#!/usr/bin/perl -w

BEGIN {
	use lib $ENV{'PERL5LIB'};
};

use strict;
use CGI qw/:standard/;
use CGI::Carp qw(fatalsToBrowser);
use Common qw(
    dumpVar
    doTemplate
    $templateDir
    sendMessage
    sanitizeCaseNumber
    getConfig
    inArray
    getSystemType
    returnJson
    getUser
    checkLoggedIn
    getSession
    createTab
);
use File::Basename;
use DB_Functions qw (
    dbConnect
    getData
    doQuery
    getDataOne
    eFileInfo
    getCaseInfo
    getDivInfo
    getDivsLDAP
    log_this
    getSubscribedQueues
	getSharedQueues
	getQueues
);
use Images qw (
    pdf_info
);
use EService qw (
    createFilingXml
);
use File::Copy;

use Data::Dumper qw(Dumper);

use MIME::Lite;

use Mail::RFC822::Address qw(valid validlist);

my $info = new CGI;
print $info->header;

my %params = $info->Vars;

my $user = getUser();
my $fdbh = dbConnect("icms");

my @myqueues = ($user);
my @sharedqueues;

getSubscribedQueues($user, $fdbh, \@myqueues);
getSharedQueues($user, $fdbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;

my $wfcount = getQueues(\%queueItems, \@allqueues, $fdbh);

my $division = $info->param('divid');
my $casestyle = $info->param('casestyle');
my $casenum = $info->param('casenum');

my ($sendername,$senderaddress,$senderphone) = split(/\|/,$info->param('sender'));

my %sender = (
	"fullname" => $sendername,
	"email_addr" => $senderaddress
);

my @recipIds = $info->param('recipId');
my @addlRecips = $info->param('addlRecip');
my @newRecips = $info->param('newRecip');

my @recipients = ();
getRecipients (\@recipIds,\@recipients,$casenum, \@addlRecips, \@newRecips, $info->param('store'));

my @uploadFiles;
if (!$params{'noAttach'}) {
    doFileUploads($info, \@uploadFiles, "attach-file");
}

# Ok, now we're actually ready to send the message!
# Use a specified alternate sender.
if ($info->param('altSender') ne "") {
	$sender{'fullname'} = "";
	$sender{'email_addr'} = $info->param('altSender');
}

my @ccs;
push(@ccs, \%sender);

my %data;

# Is it an amended filing?
if (defined($params{'filingid'})) {
    $data{'docID'} = $params{'filingid'};
    $data{'filingdate'} = $params{'filingdate'};
}

$data{'systemType'} = getSystemType();

if ($info->param('altSender') eq "") {
	$data{'division'} = $division;
	$data{'divphone'} = $senderphone;
}
$data{'casestyle'} = $casestyle;
$data{'casenum'} = $casenum;
$data{'orders'} = \@uploadFiles;

# Add additional comments if they're defined
if (defined($params{'addlcomments'})) {
	# Strip any leading/trailing whitespace
	$params{'addlcomments'} =~ s/^\s+//g;
	$params{'addlcomments'} =~ s/\s+$//g;
	if (length($params{'addlcomments'})) {
		# Replace newlines with <br> since it's an HTML email
		$params{'addlcomments'} =~ s/\r\n/<br>/g;
		$data{'addlcomments'} = $params{'addlcomments'};
	}
}

my $msgBody;

if ($params{'noAttach'}) {
    $msgBody = $data{'addlcomments'};
} else {
    $msgBody = doTemplate(\%data,"$templateDir/eservice","eservice-email.tt",0);   
}

my $subject;

if (defined($params{'msgSubject'})) {
    $subject = $params{'msgSubject'};
} else {
    $subject = "SERVICE OF COURT DOCUMENT CASE No.: $casenum";
}

# Is it an emergency filing?
if ((defined($params{'emergency'}) && ($params{'emergency'} == 1))) {
	$subject = "EMERGENCY - SERVICE OF COURT DOCUMENT CASE No.: $casenum";
}

my @goodRecipients;
my @badRecipients;
foreach my $r (@recipients) {
	if (valid($r->{'email_addr'})) {
		push(@goodRecipients, $r);
	}
	else{
		push(@badRecipients, $r);
	}
}

$data{'goodRecipients'} = \@goodRecipients;
$data{'badRecipients'} = \@badRecipients;

if (scalar(@goodRecipients)) {
    sendMessage(\@goodRecipients,\%sender,\@ccs,$subject,$msgBody,\@uploadFiles);
    my $user = getUser();
    my $docCount = scalar(@uploadFiles);
    my $recipCount = scalar(@goodRecipients);
    log_this('JVS','e-Service',"User $user e-Served $docCount documents to $recipCount in case $casenum", $ENV{'REMOTE_ADDR'});
}

$data{'foundError'} = 0;

if (defined($params{'clerkFile'})) {

    my @sends;
    foreach my $file (@uploadFiles) {
        if (defined($file->{'pages'})) {
            push(@sends, $file);
        }
    }
    
    if (scalar(@sends)) {
        $data{'sends'} = \@sends;
        
        my $pdbh = dbConnect("portal_info");
    
        $casenum = sanitizeCaseNumber($casenum);
    
        my $ucn = $casenum;
        if ($casenum =~ /^50/) {
            $ucn =~ s/-//g;
        } 

        my $user = getUser();
        my $efile_user = $params{'efile_as'};
        
        my $eFileInfo = eFileInfo($efile_user, $pdbh);
        
        # Is it an emergency filing?
        if ((defined($params{'emergency'}) && ($params{'emergency'} == 1))) {
            $eFileInfo->{'emergency'} = 1;
        }

        
        my $caseInfo = getCaseInfo($casenum);
        
        if (!defined($caseInfo->{'DivisionID'})) {
            # No division?  See if we can find it in AD for the user
            my @divs;
            getDivsLDAP(\@divs, $user);
            $caseInfo->{'DivisionID'} = $divs[0];
        }
        
        my $filetime;
        if (defined($params{'filingid'})) {
            my $query = qq {
                select
                    portal_post_date
                from
                    portal_filings
                where
                    filing_id = ?
            };
            my $fd = getDataOne($query, $pdbh, [$params{'filingid'}]);
            if (defined($fd->{'portal_post_date'})) {
                $filetime = $fd->{'portal_post_date'};
            }
        } else {
            $filetime = `/bin/date +"%FT%H:%M:%S.%N%:z"`;
            chomp $filetime;   
        }
        
        my $fileXml = createFilingXml(\@sends, $user, $casenum, $ucn, $pdbh, $eFileInfo, $caseInfo, $filetime, $params{'filingid'});
        
        my $filing = `/usr/bin/php /var/jvs/icms/bin/portal/fileTemplate.php -f $fileXml`;
    
        my $xs = XML::Simple->new();
		
		my $ref;
		eval {
            $ref = $xs->XMLin($filing);
		};
		
		# If there was an error, let's wait a few seconds and try it one more time before we send an error e-mail
		if ($@) {
			sleep 3;
			$filing = `/usr/bin/php var/jvs/icms/bin/portal/fileTemplate.php -f $fileXml`;
    
	        $xs = XML::Simple->new();
			
			$ref;
			eval {
	            $ref = $xs->XMLin($filing);
			};
		}
        
        # There was STILL an error
        if ($@) {
            $data{'foundError'} = 1;
            
            if($params{'doc_id'}){
	        	my $idbh = dbConnect("icms");
	            #update wf queue also
	            my $wf_query = qq{
	            	UPDATE workflow
	                SET finished = 1
	                WHERE doc_id = $params{'doc_id'}
	            };
	                
	            doQuery($wf_query, $idbh);
			}
			
            notifyGeeks($@, $filing, $fileXml, \%sender);
        } else {
            my $response = $ref->{'s:Body'}->{'BulkReviewFilingResponse'};
            my $errorCode = $response->{'MessageReceiptMessage'}->{'ecf:Error'}->{'ecf:ErrorCode'};
            
            if ($errorCode) {
            	$data{'foundError'} = 1;
            	$data{'sends'} = 0;
                my $errorString = $response->{'MessageReceiptMessage'}->{'ecf:Error'}->{'ecf:ErrorText'};
                print "<br/><strong><p style=\"color: red\">There was an error filing.  The response received was:</p></strong>";
                print "<strong><p style=\"color: red\">" . $errorString . "</p></strong><br/>";
            } else {
                $data{'eFiled'} = 1;
                
                my $filingID = $response->{'MessageReceiptMessage'}->{'nc:DocumentIdentification'}[0]->{'nc:IdentificationID'};
                $data{'filingID'} = $filingID;
                
                my $filingDate = $response->{'MessageReceiptMessage'}->{'nc:DocumentReceivedDate'}->{'nc:DateTime'};
        
                # Start the transaction
                $pdbh->begin_work;
                
                # First, insert the record into the portal_filings table
                my $query = qq {
                    replace into
                        portal_filings (
                            user_id,
                            portal_id,
                            filing_id,
                            casenum,
                            case_style,
                            clerk_case_id,
                            filing_date,
                            portal_post_date,
                            filing_status,
                            status_date,
                            status_dscr
                        )
                        values (
                            ?,?,?,?,?,?,?,?,?,NOW(),'Pending Filing'
                        )
                };
                
                my @vals = ($user, $eFileInfo->{'portal_id'}, $filingID, $ucn, $caseInfo->{'CaseStyle'},
                            $caseInfo->{'CaseNumber'}, $filingDate, $filetime, 'Pending Filing');
                doQuery($query, $pdbh, \@vals);
                
                if($params{'doc_id'}){
	                my $idbh = dbConnect("icms");
	                #update wf queue also
	                my $wf_query = qq{
	                	UPDATE workflow
	                	SET efile_submitted = 1,
	                	finished = 1,
	                	portal_filing_id = ?
	                	WHERE doc_id = ?
	                };
	                
	                doQuery($wf_query, $idbh, [$filingID, $params{'doc_id'}]);
                }
                
                my $user = getUser();
                my $docCount = scalar(@sends);
                log_this('JVS','e-Service',"User $user e-Filed $docCount documents in case $casenum (Filing ID $filingID)", $ENV{'REMOTE_ADDR'});
                
                # Then insert each attachment
                foreach my $file (@sends) {
                    $query = qq {
                        replace into
                            pending_filings (
                                filing_id,
                                file_name,
                                document_group,
                                document_type,
                                document_id,
                                attachment_id,
                                binary_size,
                                base64_attachment
                            )
                            values (
                                ?,?,?,?,?,?,?,?
                            )
                    };
                    doQuery($query, $pdbh, [$filingID, $file->{'shortname'}, $file->{'documentgroup'}, $file->{'filedesc'}, $file->{'docID'},
                                            $file->{'attachID'}, $file->{'binary_size'}, $file->{'encodedBase64'}]);
                }
                
                $pdbh->commit;
            }
        }
    }      
}

my $session = getSession();
#Remove all our old order stuff
$session->unregister("docid");
$session->unregister("formData");
$session->unregister("form_data");
$session->unregister("order_html");
$session->unregister("case_caption");
$session->unregister("cclist");
$session->unregister("isOrder");
$session->unregister("ucn");
$session->unregister("caseid");
$session->unregister("formid");
$session->unregister("pdf_file");
$session->unregister("signature_html");

my $sess_tabs = $session->get('tabs');
foreach my $tab_key (keys %{$sess_tabs}){
	if($sess_tabs->{$tab_key}->{'name'} eq $casenum){
		foreach my $inner_tab_key (keys %{$sess_tabs->{$tab_key}->{'tabs'}}){
			if($sess_tabs->{$tab_key}->{'tabs'}->{$inner_tab_key}->{'name'} eq "Order Creation"){ 
				delete $sess_tabs->{$tab_key}->{'tabs'}->{$inner_tab_key};
			}
		}
	}
}

$session->save();

createTab($casenum, "/cgi-bin/search.cgi?name=" . $casenum, 1, 1, "cases",
{ 
	"name" => "e-Service",
	"active" => 1,
	"close" => 1,
	"href" => "/cgi-bin/eservice/eService.cgi?case=" . $casenum . "&showOnly=0",
	"parent" => $casenum
});
$session = getSession();

$data{'wfCount'} = $wfcount;
$data{'active'} = "cases";
$data{'tabs'} = $session->get('tabs');

doTemplate(\%data, "$templateDir/top", "header.tt", 1);
doTemplate(\%data,"$templateDir/eservice","eservice-sent.tt",1);

undef @recipients;
undef @goodRecipients;
undef @badRecipients;
undef %sender;

exit;


sub notifyGeeks {
    my $errMsg = shift;
    my $response = shift;
    my $fileXml = shift;
    my $sender = shift;
    my $user = getUser();
    
    move($fileXml, "/var/www/portalRetries/");
    
    my @recipients = (
        { email_addr => 'lkries@pbcgov.org' }
    );
    
    my $subject = "IMPORTANT!! Portal e-Filing Error!";
    
    my $msgBody  = "A portal filing has failed!  It was filed with the XML document $fileXml, which has been ".
        "moved to /var/www/portalRetries .\n\nThe error message received was:\n-----\n$errMsg\n-----\n\n";
    $msgBody .= "The response from the server was:\n-----\n$response\n-----\n\n";
    $msgBody .= "The filing was made by user " . $user . "\n\n";
    $msgBody .= "Please look into it ASAP.  That is all.";
    
    sendMessage(\@recipients,$sender,undef,$subject,$msgBody,undef,1,0);
}

sub sendClerkFiles {
    my $casenum = shift;
    my $sender = shift;
    my $docs = shift;
    
    my $ucn = $casenum;
    $casenum =~ s/-//g;
    
    my $clerkEmail;
    my $caseType;
    if ($casenum =~ /^(\d{1,6})(\D\D)(\d{0,6})(.*)/) {
        $caseType = $2;
    } else {
        return 0;
    }
    
	my $conf = XMLin("$ENV{'APP_ROOT'}/conf/ICMS.xml");
    my $clerkEmails = $config->{'clerkEmail'};
    my $clerkAddr;
    
    foreach my $type (keys %{$clerkEmails}) {
        my $courtTypes = $clerkEmails->{$type}->{'CourtTypes'};
        my @temp = split(",", $courtTypes);
        if (inArray(\@temp, $caseType)) {
            $clerkAddr = $clerkEmails->{$type}->{'EmailAddr'};
            last;
        }
    }
    
    my %recip = ('email_addr' => $clerkAddr);
    
    my @recipients = (\%recip);
    
    foreach my $doc (@{$docs}) {
        # Because sendMessage wants the attachments as an array ref
        my $tmparr = [];
        my $subject = "$doc->{'filedesc'}, CASE $casenum, $doc->{'pages'} pages";
        
        push(@{$tmparr}, $doc);
        
        my %data;
        $data{'orders'} = $tmparr;
        $data{'casenum'} = $ucn;
        
        my $msgBody = doTemplate(\%data,"$templateDir/eservice","eservice-clerkmail.tt",0);
        
        sendMessage(\@recipients,$sender,undef,$subject,$msgBody,$tmparr);    
    }
}

sub getRecipients {
	my $recipIds = shift;
	my $recipref = shift;
	my $casenum = shift;
	my $addlRecips = shift;
	my $newRecips = shift;
	my $store = shift;

	my $dbh = dbConnect("eservice");
	
	$casenum =~ s/^50-//g;
	$casenum =~ s/-//g;

	# Whew!  Ready to get info.
	if (scalar(@{$recipIds})) {
		my $instring = join (",", sort(@{$recipIds}));

		my $qcasenum = $dbh->quote($casenum);

		my $query = qq {
			select
				u.first_name,
				u.middle_name,
				u.last_name,
				u.bar_num,
				e.email_addr,
				e.email_addr_id
			from
				users u,
				email_addresses e
			where
				u.login_id in ($instring)
				and u.login_id = e.email_addr_id
			UNION
			select
				u.first_name,
				u.middle_name,
				u.last_name,
				u.bar_num,
				e.email_addr,
				e.email_addr_id
			from
				unreg_bar_members u,
				email_addresses e
			where
				u.email_addr_id in ($instring)
				and u.email_addr_id = e.email_addr_id
		};
		getData($recipref,$query,$dbh);
	}

	foreach my $address(@{$recipref}) {
		my @temp = split(/[;,\ ]+/, $address->{'email_addr'});
		foreach my $piece (@temp) {
			if (valid($piece)) {
				$address->{'email_addr'} = $piece;
				last;
			}
		}

		my $fullname;
		# Build a full name string
		if ($address->{'middle_name'} eq "") {
			$fullname = sprintf ("%s %s", $address->{'first_name'}, $address->{'last_name'});
		} else {
			$fullname = sprintf ("%s %s %s", $address->{'first_name'}, $address->{'middle_name'}, $address->{'last_name'});
		}

		if ((defined($address->{'suffix'})) && ($address->{'suffix'} ne "")) {
			$fullname .= ", $address->{'suffix'}";
		}
		$address->{'fullname'} = $fullname;
	}

	if (defined($addlRecips)) {
		foreach my $addl (@{$addlRecips}) {
			my $temp = {};
			$temp->{'email_addr'} = $addl;
			push(@{$recipref}, $temp);
		}
	}
	
	if (defined($newRecips)) {
		foreach my $addl (@{$newRecips}) {
			my $temp = {};
			$temp->{'email_addr'} = $addl;
			push(@{$recipref}, $temp);
		}
		
		if ((defined($store)) && (scalar(@{$newRecips}))) {
			# We've been told to store the values.  First, clear out any that
			# might have been stored on a previous run.
			my $origAc = $dbh->{AutoCommit};
			$dbh->{AutoCommit} =  0;
			
			# Need to build an array of quoted values so we can build a string for the query
			my @in;
			foreach my $addl (@{$newRecips}) {
				push (@in, "'$addl'");
			}
			my $inStr = join (",", @in);
			
			my $query = qq {
				delete from
					reuse_emails
				where
					casenum = ?
					and email_addr in ($inStr)
			};
			doQuery($query,$dbh,[$casenum]);

			# Then add the new addresses
			foreach my $addl (@{$newRecips}) {
				$query = qq {
					replace into
						reuse_emails
						(
							casenum,
							email_addr
						)
					values
						(?,?)
				};
				doQuery($query,$dbh,[$casenum, $addl]);
			}
			$dbh->commit;
			# Put the AutoCommit back like we found it
			$dbh->{AutoCommit} = $origAc;
		}
	}
}



sub doFileUploads {
	my $info = shift;
	my $fileref = shift;
	my $filematch = shift;
    
	if (!defined($filematch)) {
		$filematch = "attach-file-";
	}

	my $safe_filename_characters = "a-zA-Z0-9_.-";

	# Don't need the uploaded files visible to the webserver
	my $uploaduser = getUser();
	my $upload_base = "/tmp";

	# Keep users from possibly stomping on each other's uploads
	my $upload_dir = "$upload_base/$uploaduser";
	if (!-d $upload_dir) {
		mkdir $upload_dir;
	}

	my %params = $info->Vars;
    
    my $replacing;
    if (defined($params{'filingid'})) {
        $replacing = 1;
    }
    
	foreach my $param (keys %params) {
		
		if($param =~ /^$filematch/){
			# Get the sequence number to associate it with the file description
			my @pieces = split(/-/, $param);
			my $seq = $pieces[$#pieces];
	
			my $filename = $params{$param};
			next if ($filename eq '');
			my ($name,$path,$extension ) = fileparse ( $filename, '\..*' );
			$filename = $name . $extension;
	
			# Sanitize the filename a bit
			$filename =~ tr/ /_/;
			$filename =~ s/[^$safe_filename_characters]//g;
	
			if ($filename =~ /^([$safe_filename_characters]+)$/) {
				$filename = $1;
			} else {
				die "Filename contains invalid characters";
			}
	
			# And upload the file.
	        my $targetFile;
	        if ($replacing && ($params{$param} =~ /\/var\/www\/html\/tmp/)) {
	        	# THis is a replacement filing, and this file is already on the server.
	            $targetFile = $params{$param};
	        } 
	        elsif ($params{$param} =~ /\/case\/uploads/) {
	        	# This is an attachment.  It already exists on the server.
	            $targetFile = $params{$param};
	        }else {
	        	my $upload_filehandle = $info->upload($param);
	            $targetFile = "$upload_dir/$filename";
	                
	            open (UPLOADFILE, ">$targetFile") ||
	            	die "Unable to upload file '$params{$param}: $!";
	            binmode UPLOADFILE;
	            while (<$upload_filehandle>) {
	            	print UPLOADFILE;
	           	}
	            close UPLOADFILE;   
	        }
	          
	        my $orderdesc;
	        my $portaldesc;
	        my $docgroup;
	        if (defined($params{'filingid'})) {
	        	($orderdesc, $portaldesc, $docgroup) = split("~", $params{"file-desc-$casenum-$seq"});
	        }
	        else{
	        	($orderdesc, $portaldesc, $docgroup) = split("~", $params{"file-desc-$seq"});
	        }
	        
	        if(!defined($docgroup) || ($docgroup eq "")){
	        	$docgroup = "Judiciary";
	        }
	        
	        if(!defined($orderdesc) || ($orderdesc eq "")){
	        	$orderdesc = "ORDER";
	        }
	
	        # Calculate the number of pages if it's a PDF; we need this info to send to the Clerk
	        if (!-e $targetFile) {
	            # Try looking in /var/www/html
	            $targetFile = sprintf("/var/www/html%s", $targetFile);
	        }
	        
	        my $pdfinfo = pdf_info($targetFile);
	        my $pagecount = undef;
	        
	        if (scalar(@{$pdfinfo})) {
	            foreach my $line (@{$pdfinfo}) {
	                next if ($line !~ /^Pages/);
	                chomp($line);
	                $pagecount = (split(/\s+/,$line))[1];
	                last;
	            }
	        }
			
			my %fileinfo = (
				"filename" => $targetFile,
				"filedesc" => $orderdesc,
				"portaldesc" => $portaldesc,
	            'documentgroup' => $docgroup,
	            "pages" => $pagecount,
	            "shortname" => basename($targetFile)
			);
	
			$fileref->[$seq - 1] = \%fileinfo;
	        
			#push(@{$fileref},\%fileinfo);
		}
		elsif($param eq 'genPdf'){
			#my $targetFile = $params{'genPdf'};
        	my $targetFile = sprintf("/var/www/html%s", $params{'genPdf'});
        
	        $targetFile =~ s/\'/\\\'/g;
	        
	        my ($orderdesc, $portaldesc, $docgroup) = split("~", $params{'genDocketDesc'});
	        
	        if(!defined($docgroup) || ($docgroup eq "")){
	        	$docgroup = "Judiciary";
	        }
	        
	        if(!defined($orderdesc) || ($orderdesc eq "")){
	        	$orderdesc = "ORDER";
	        }
	        
	        my $pdfinfo = pdf_info($targetFile);
	        my $pagecount = undef;
	        
	        if (scalar(@{$pdfinfo})) {
	            foreach my $line (@{$pdfinfo}) {
	                next if ($line !~ /^Pages/);
	                chomp($line);
	                $pagecount = (split(/\s+/,$line))[1];
	                last;
	            }
	        }
	        
	        my %fileinfo = (
				"filename" => $targetFile,
				"filedesc" => $orderdesc,
				"portaldesc" => $portaldesc,
	            'documentgroup' => $docgroup,
	            "pages" => $pagecount,
	            "shortname" => basename($targetFile)
			);
	
			push(@{$fileref}, \%fileinfo);
		}

	}

}
