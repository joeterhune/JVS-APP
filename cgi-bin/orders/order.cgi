#!/usr/bin/perl

BEGIN {
	use lib "$ENV{'PERL5LIB'}";
}

use strict;

use ICMS;
use CGI;
use Cwd;
use Common qw(
	dumpVar
	inArray
    stripWhiteSpace
	buildName
	getShowcaseDb
);
use CGI::Carp qw(fatalsToBrowser);
use Orders qw(
	buildReturnAddr
	getExtraParties
	getCaseDiv
	getEsigs
);

use Showcase qw (
    getPropertyAddress
);

use DB_Functions qw (
	dbConnect
	getData
	getDataOne
	findCaseType
	getDbSchema
);

our $db = getShowcaseDb();
our $dbh = dbConnect($db);
our $schema = getDbSchema($db);

my $DPATH="/usr/local/icms/cgi-bin/orders/forms";
my $SIGS="/usr/local/icms/cgi-bin/orders/sigs/";
my $FFEXT=".form";
my $maxcopies = 10;  # configurable!  don't allow more than 10 copies to be produced by the order generator.

my $nocheck = 0;

#  write active pro se and attorneys for asking for copies
sub write_parties {
    my $caseid = shift;
	my $fieldref = shift;
    my $nocheck = shift;
    my $case_id = shift;
    # get active parties

    my $query = qq {
		select
			p.PersonID,
			p.PartyType,
			a.Represented_PersonID
		from
			$schema.vAllParties p
		left outer join
			$schema.vAttorney a	
				ON p.CaseID = a.CaseID
				AND p.PartyType = a.Represented_PartyType 
				AND p.PersonID = a.Represented_PersonID
		where
			p.CaseID='$caseid'
			and p.PartyType in ('DFT','PLT','ATTY','PET','RESP','APNT','APLE', 'HYBRID')
			and Active = 'Yes'
			AND (Discharged = 0 OR Discharged IS NULL)
    };

    my(@parties)=sqllist($query, undef, $dbh);

    my @list;
    # for each pidm, see if there's an atty.  if not, that person is pro se.
    foreach (@parties) {
		my($id,$code,$assoc)=split '~';
		my $found = 0;
		if($code ne 'ATTY') {
			if($assoc eq $id) {
				$found++;
			}
			if(!$found) {
				# didn't find an atty - - so, pro se.  put in list.
				push @list,"$id~$code";
			}
		} else {
			push @list,"$id~$code";  # is an atty
		}
    }

    @parties=();

    # for each party in the list, get the address and rebuild the parties list
    foreach my $item (@list) {
		my($id,$code)=split ('~', $item);
		my $fullname;
		my $query = qq {
			select
				LastName,
				FirstName,
				MiddleName,
				PersonID
			from
				$schema.vAllParties p
			where
				PersonID = ?
		};
		my $personRec = getDataOne($query,$dbh,[$id]);

		if ((!defined($personRec->{'FirstName'})) ||
			($personRec->{'FirstName'} eq "")) {
			$fullname=$personRec->{'LastName'};
		} else {
			if ((!defined ($personRec->{'MiddleName'})) ||
				($personRec->{'MiddleName'} eq '')) {
				$fullname = sprintf("%s %s",$personRec->{'FirstName'},
									$personRec->{'LastName'});
			} else {
				$fullname = sprintf("%s %s %s",$personRec->{'FirstName'},
									$personRec->{'MiddleName'},
									$personRec->{'LastName'});
			}
		}

		my $address = build_address($id, $case_id);
		$address =~ s/\s+/ /g;
		push @parties,"$fullname~$address";
    }

	# Are there any extra parties (delimited by /extraparties and /endparties)?
	getExtraParties(\@parties,$fieldref);

    # almost done!  add a couple of blank address blocks
    push(@parties,"");
    push(@parties,"");

    my $i=0;
    foreach my $party (@parties) {
		my ($pname,$addr1,$addr2,$city, $state,$zip,$confidential)=split '~',$party;
		my $checked;
		if (($nocheck) || ($pname eq "")) {
			$checked="";
		} else {
			$checked="checked=\"checked\"";
		}
		
		print qq {
			<tr class="address">
                <td>
                    <input type="checkbox" name="check$i" $checked/>
                    <input type="hidden" name="conf$i" value="$confidential"/>
                </td>
                <td class="inputcol">
                    <input type="text" name="name$i" value="$pname" size="40"/>
                </td>
        };
        if ($confidential) {
            print qq {
                <td style="text-align: left; color: red">CONFIDENTIAL ADDRESS: will not be included in cc: list</td>
            };
        } else {
            print qq {
                <td>&nbsp;</td>  
            };
        }
        
        print qq{
			</tr>
            <tr class="address"><td></td><td><input type="text" name="addr1$i" value="$addr1" size="40"/></td></tr>
		};
		
		if ($addr2 ne "") {
			print qq{
                <tr class="address"><td></td><td><input type="text" name="addr2$i" value="$addr2" size="40"/></td></tr>
            };
		} else {
			print qq{
                <tr class="address"><td></td><td><input type="text" name="addr2$i" size="40"/></td></tr>
            };
		}
		
		if($city eq "" and $state eq "" and $zip eq "") {
			print qq{
                <tr class="address"><td></td><td><input type="text" name="csz$i" value=" " size="40"/></td></tr>
                    <tr><td>&nbsp;</td></tr>
            };
		} else {
			print qq{
                <tr class="address"><td></td><td><input type="text" name="csz$i" value="$city, $state $zip" size="40"/></td></tr>
                <tr class="address"><td>&nbsp;</td></tr>
            };
		}
		$i++;
	}
    return $i;
}

# pass the pidm of the party
sub build_address {
	my $id = shift;
	my $case_id = shift;
    
	my ($line1,$line2,$line3);
	# Check for the address types in order, and return the first one found.
    #my @addrTypes = ('Mailing','Business','Residence','Property Address','Alternative');
    #foreach my $type (@addrTypes) {
        #if ((my $addr = get_address($id, $type, $case_id)) ne "") {
        if ((my $addr = get_address($id, undef, $case_id)) ne "") {
            return ($addr);
        };
    #}
	return ("");
}

# pass the pidm and address type to get of the party
sub get_address {
	my $id = shift;
	my $type = shift;
	my $case_id = shift;

	my $addr = "";
	my ($addr1,$addr2,$cityinfo,$stateinfo,$zipinfo);
	my $query = qq {
		select
			Address1,
			Address2,
			City,
			State,
			ZipCode,
			ConfidentialAddress AS Confidential
		from
			$schema.vAllPartyAddress
		where
			PartyID = '$id'
			AND CaseID = $case_id
			and ((DefaultAddress='Yes') or (DefaultAddress is null))
	};
	
	# AND AddrType = 
    
    my $addrInfo = getDataOne($query, $dbh);
    
    if (defined($addrInfo)) {
        $addr1 = stripWhiteSpace(sprintf("%s", $addrInfo->{'Address1'}));
        $addr2 = stripWhiteSpace(sprintf("%s", $addrInfo->{'Address2'}));
        my $city = $addrInfo->{'City'};
        my $st = $addrInfo->{'State'};
        my $zip = $addrInfo->{'ZipCode'};
        if ($addr2 eq "") {
            $addr="$addr1~";
        } else {
            $addr="$addr1~$addr2";
        }
        $addr.="~$city~$st~$zip~$addrInfo->{'Confidential'}";
    }
	return $addr;
}


# write the copy list block (not the same as parties!)
sub write_copylist {
    my($caseid,@fields)=@_;
	my @copylist=();
	my ($extra,$checked);
	my $found=0;
	for (my $i=0; $i < scalar @fields; $i++) {
		my ($fieldname,$fielddesc,$cookie,$type,$length,$comment,$choices,$initval)=split '~',$fields[$i];
		if ($fieldname=~/^\/copystart/) {
			$found++;
			while (!($fieldname=~/^\/copyend/) and $i < scalar @fields) {
				$i++;
				# "extra" is the number of extra lines to put on the form for the copy list
				# (/copyend~5, for example)
				($fieldname,$extra)=split '~',$fields[$i];
				push(@copylist,"$fieldname~$extra");
			}
		}
	}

	if($found != 0) {
		$extra = (split '~',$copylist[scalar @copylist - 1])[1];
		# show each one...
		# don't do the '/copyend' line (last one)
		my $j=0;
		my $i=0;
		for ($i=0; $i < (scalar @copylist) -1; $i++) {
			my($addr,$o) = split '~',$copylist[$i];
			$addr=~s/'/`/g;  # replace all apostrophes with escape apostrophe
			my $div = getdiv($caseid);  # need to get the division
			my $start = index $addr,"%division%";
			my $end = $start + 10;
			if($start != -1) {
				my $newline= substr $addr,0,$start;
				$newline.=$div;
				$newline.=substr $addr,$end;
				$addr=$newline;
			}
			if (($nocheck) || ($addr eq "")) {
				$checked="";
			} else {
				$checked="checked";
			}
			print qq{
                <tr>
                    <td>
                        <input type="checkbox" name="eccheck$i" $checked/>
                    </td>
                    <td colspan="2">
                        <input type="text" name="ecaddr$i" value="$addr" size="100"/>
                    </td>
                </tr>
            };
			$j++;
		}
		# and give extra fill lines
		for ($j=1; $j <= $extra; $j++) {
			print qq{
                <tr>
                    <td>
                        <input type="checkbox" name="eccheck$i"/>
                    </td>
                    <td colspan="2">
                        <input type="text" name="ecaddr$i" value="" size="100"/>
                    </td>
                </tr>
            };
			$i++;
		}
		print "<tr><td>&nbsp;</td></tr>";
		return $i;
	} else {
		return 0;
	}
}


# build selectable children list if the tag is in the FIELDS section
sub write_kids {
    my ($caseid,@fields)=@_;
	my @kids=();
	my ($extra,$checked,$cnt,$fieldname);
	my $found=0;
	my $showdob = undef;

	for (my $i=0; $i < scalar @fields; $i++) {
		($fieldname,$cnt,$showdob)=split '~',$fields[$i];
		if ($fieldname=~/^\/selectkids/) {
			$found++;
			$extra = $cnt;
			if (defined($showdob)) {
				$showdob = int($showdob);
			}
			last;
		} else {
			$showdob = undef;
		}
	}

    if($found != 0){
		# get active CHILD parties
		my $query = qq {
			select
				FirstName,
				MiddleName,
				LastName
				PersonID
			from
				$schema.vAllParties
			where
				CaseNumber='$caseid'
				and PartyType = 'CHLD'
				AND Active = 'Yes'
				and (Discharged = 0 OR Discharged IS NULL)
		};
		my(@parties)=sqllist($query, undef, $dbh);
		foreach my $p (@parties) {
			my $fullname;
			if ($p->{'FirstName'} eq "") {
				$fullname = $p->{'LastName'};
			} else {
				$fullname="$p->{'LastName'}, $p->{'FirstName'} $p->{'MiddleName'}";
			}
			push @kids,"$fullname";
		}

		# almost done!  add some empty lines for more names - - based on /selectkids tag
		for (my $i=0; $i<$extra; $i++ ){
			push(@kids,"");
		}

		my $i=0;
		if(@kids >0) {
			my $usedob = "";

			if (defined($showdob) && ($showdob)) {
				$usedob = " and DOB";
			}

			my $childstr = "Children";
			if (scalar(@kids) == 1) {

			}
			print "<h3>Select $childstr" . $usedob . ":</h3>\n";

            print "<table>\n";
			foreach my $kid (@kids) {
				my ($pname)=split '~',$kid;
				my $checked;
				if ($pname eq "") {
					$checked="";
				} else {
					$checked="checked";
				}
				print "<tr>\n<td>\n<input type=checkbox name=skcheck$i $checked>\n</td>\n";
				print "<td>\n<input type=text name=skname$i value='$pname' size=40>\n</td>\n";
				if (defined($showdob) && ($showdob)) {
					print "<td>\n<input type=text name=skdob$i size=15>\n</td>\n";
				}
				print "</tr>\n";
				$i++;
			}

			print "</table>\n<br/>\n";
			return $i;
        }
	}
	return 0;
}

sub getdiv {
	# get the judge name and div from parties list - find the active judge for this case
	my $caseid = shift;
    
    my $query = qq {
        select
            DivisionID
        from
            $schema.vCase
        where
            CaseNumber = ?
    };
    
    my $div = getDataOne($query, $dbh, [$caseid]);
    
    return ($div->{'DivisionID'});
}


#########################################################
#                     MAIN PROGRAM
#########################################################

my $info=new CGI;

my $ucn = $info->param("ucn");  # a given
my $case_id = $info->param("caseid"); 

my %params = $info->Vars;

my $casenum=$ucn;
$casenum=~s#-##g;

my $caseid = $ucn;
#$caseid=~ tr/-//d;

my $dbname = $db;
my $dbtype = "showcase";
my $extCaseId = $ucn;
my $caseDiv = getCaseDiv($dbh, $caseid, "showcase", $schema);
my $caseType = findCaseType($ucn);

print $info->header;

my $rpttype=$info->param("rpttype"); # if called from a reload
my $lev=$info->param("lev");

if ($lev eq "") { $lev=5; }
my $prev=$lev-1;

my %forms;
my @fields;
my $thisform;

my $returnAddr = undef;
my $propAddr = undef;

# look for new .form files
opendir MYDIR, $DPATH;
my @contents = grep /$FFEXT$/ && -f "$DPATH/$_" , readdir MYDIR;
closedir MYDIR;

# Need a mechanism to tell it to use the new (RTF) method. Default to the
# "old" way.
my $nextcgi = "order3.cgi";
my $showRtfOption = 0;

my $ttype;

my $found = 0;

foreach my $item (@contents) {
    open INFILE,"$DPATH/$item" or die "Unable to open file '$DPATH/$item': $!\n\n";
    while (<INFILE>) {
        chomp;
        next if (/^#/);
        next if (/^ORDER/);
        if (/^FIELDS/) {
            last;
        }
        chomp;
        my ($title,$formfile,$div,$vars,$county,$evtype,$cDivs,$doctdesc);
        ($title,$formfile,$div,$vars,$county,$evtype,$ttype,$cDivs,$doctdesc)=split '~';
        
        
        if (defined($cDivs)) {
            $cDivs =~ s/\s+//g;
			
		 }
			
		if (($cDivs =~ /^all$/i) || ($cDivs eq "") ) {
			
				$forms{$formfile}="$title~$div~$vars~$county~$evtype~$ttype~$cDivs~$doctdesc";
			
			
        } else {
           # Divs were specified
				my @targetDivs = split(/,/, $cDivs);
				my @notDivs;
				
				foreach $div (@targetDivs){
				  if($div =~ /!/){
						 push(@notDivs, $div);
						 
						 my $index = 0;
									  $index++ until $targetDivs[$index] eq $div;
									  splice(@targetDivs, $index, 1);
				  }
				}
				
				if(!@targetDivs && !inArray(\@notDivs, "!" . $caseDiv)){
				  $forms{$formfile}="$title~$div~$vars~$county~$evtype~$ttype~$cDivs~$doctdesc";
				} elsif(inArray(\@targetDivs,$caseDiv) && !inArray(\@notDivs, "!" . $caseDiv)) {
					$forms{$formfile}="$title~$div~$vars~$county~$evtype~$ttype~$cDivs~$doctdesc";
				} else {
					close INFILE;
					next;
				}

			
        }
            
		$thisform=$formfile;
    }
    
	# when a form is selected, get its form fields.
    if($rpttype eq $thisform){
        $found++;
        while (my $line = <INFILE>) {
            next if ($line =~ /^#/);
            last if ($line =~ /^FORM/);
            if ($line =~ /^\/returnAddress/) {
                # Split the line into 2 parts - the first we don't need, the second
                # is the tilde-delimited return address.
                chomp $line;
                my $foo;
                ($foo,$returnAddr) = split(/~/,$line,2);
            }
            if ($line =~ (/^\/nocheck/)) {
                # Don't check the party/cc checkboxes by default.
                $nocheck = 1;
            }
            if ($line =~ /^USERTF/) {
                $nextcgi = "order3.cgi";
                $showRtfOption = 1;
                last;
            }
            if ($line =~ /^JAS/) {
                last;
            } # skip JA section--not relevent here
            chomp;
            my ($fieldname,$fielddesc,$cookie,$type,$length,$comment, $choices,$initval)=split ('~', $line);
            push @fields,"$fieldname~$fielddesc~$cookie~$type~$length~$comment~$choices~$initval";
        }
	}
    close(INFILE);
}

#
# then, get the orders.conf file - - that way, we'll have any fields defined in forms first (like we want to!)
#
# (there is no longer support for having forms defined within orders.conf!)
#
open INFILE,"$DPATH/orders.conf" or die "Unable to open file '$DPATH/orders.conf': $!\n\n";
while (<INFILE>) {
    chomp;
    if (/^#/) {
        next;
    }
    if (/^ORDERS/) {
        next;
    }
    if (/^FIELDS/) {
        last;
    }
    
    my($title,$formfile,$div,$vars,$county,$evtype,$ttype)=split '~';
    $forms{$formfile}="$title~$div~$vars~$county~$evtype~$ttype";
}

while (<INFILE>) {
    chomp;
    if (/^#/) {
        next;
    }
    if (/^JAS/) {
        last;
    } # skip JA section--not relevant here
    my ($fieldname,$fielddesc,$cookie,$type,$length,$comment,$choices,$initval)=split '~';
    push @fields,"$fieldname~$fielddesc~$cookie~$type~$length~$comment~$choices~$initval";
}

close(INFILE);

if (!defined($returnAddr)) {
    $returnAddr = buildReturnAddr($caseDiv);
}

if (!defined($propAddr)) {
    $propAddr = getPropertyAddress($case_id,$dbh,0);
    $propAddr =~ s/\n/, /g;
    $propAddr = stripWhiteSpace($propAddr);
}

print <<EOS;
<!DOCTYPE html>
<html>
<head>
<title>Create Form Order</title>
<link rel="stylesheet" type="text/css" href="/case/icms1.css?1.1"/>
<script type="text/javascript" src="https://e-services.co.Sarasota-beach.fl.us/cdn/jslib/jquery-1.11.0.js"></script>
<script src="https://e-services.co.Sarasota-beach.fl.us/cdn/jslib/jquery.cookie.js" type="text/javascript"></script>
<script src="/case/icms.js?1.1" type="text/javascript"></script>
<script src="/case/javascript/main.js?1.1" type="text/javascript"></script>
</head>
<body>
	<script type="text/javascript">
		\$(document).ready(function () {
			if ((\$('#rpttype').val() != undefined) && (\$('#rpttype').val() != "")) {
				\$('#genButton').show();
			}
			
			\$('#genButton').click(function() {
				setAutoSave(theform);
				if (\$('#usees').prop('checked') == true) {
					// The checkbox is set.  Make sure a name is selected
					if (\$('#signAs').val() == "") {
						alert("Please select a signature to apply (or un-check the checkbox)");
						return false;
					}
				}
				\$('#theform').submit();
			});
		});

		function PopUpOrder(myform,windowname) {
			if (! window.focus) return true;
			var dpi = window.screen.deviceXDPI || 96;
			var wy = screen.height-10;
			if (wy > dpi * 12) {
				wy = dpi * 12;
			}
			var wx = parseInt(wy * 0.77272);
			var xpos = screen.width-wx-10;
			var specs = 'resizable=1,toolbar=0,location=0,directories=0,status=0,menubar=0,width=' + wx + ',height=' + wy + ',top=0,left=' + xpos;
			window.open('$nextcgi',windowname,specs);
			myform.target=windowname;
			return false;
		}

		function getval(x) {
			if (document.layers) {
				return document.layers[x].value;
			} else if (document.all) {
				return document.all[x].value;
			} else if (document.getElementById) {
				return document.getElementById(x).value;
			}
		}

		function update(ucn,lev,case_id) {
		    box=document.forms[0].rpttype;
		    rpttype=box.options[box.selectedIndex].value;
		    document.location='order.cgi?ucn='+ucn+'&lev='+lev+'&rpttype='+rpttype+'&caseid='+case_id;
		}
	</script>
	
	<div>
		<a href="/case/">
			<img src="/case/icmslogo.jpg" style="border: none" alt="ICMS Logo">
		</a>
	</div>
	
	<div>
		<input type="button" name="Back" value="Back To Case" onclick="GoBack('ICMS_$prev');"/>
	</div>

<h2>Create Form Order</h2>

<form name="theform" id="theform" method="post" action="$nextcgi">
<table>
<tr><td><b>Case #</b></td><td>$ucn</td></tr>
<tr><td><b>Form</b></td><td><select id="rpttype" name="rpttype" onchange="update('$ucn','$lev','$case_id');">
<option>
EOS

# was looking for one 'div' per form.  now, it can be several.
my @formlist;

foreach my $formfile (keys %forms) {
    my ($title,$div,$vars,$county,$evtype,$ttype,$cdivs,$doctdesc,$division)=split('~',$forms{$formfile},8);
    if (length($doctdesc)) {
        $doctdesc = stripWhiteSpace($doctdesc);
    }
    my $string = "$title~$formfile~$vars~$county~$evtype~$ttype~$doctdesc";
    #print "<br><br>$string<br><br>";

		if("ALL" eq $div){
        push(@formlist,$string);
			} else {
				# see if the case number contains any of the listed divisions
				my @divlist = split ',',$div;
				foreach (@divlist) {
				
					if($ucn =~/$_/) {
						push(@formlist,$string);
						
					}
				}
			}
		
	

}

@formlist=sort @formlist;
my $sel;
my $fvars;
my $FORMDESC;
my $EVTYPE;
my $DOCTDESC;

foreach (@formlist) {
    my ($title,$formfile,$vars,$county,$evtype,$ttype,$doctdesc)=split'~';
    if ($formfile eq $rpttype) {
        $sel="SELECTED";
        $fvars=$vars;
        $FORMDESC=$title;
        chomp $FORMDESC;
        $EVTYPE=$evtype;
        chomp $EVTYPE;
        $DOCTDESC = $doctdesc;
        chomp $DOCTDESC;
    } else {
        $sel="";
    }
    print "<option value=$formfile $sel>$title\n";
}
print "</select></td></tr>\n";

my $fieldq=",$fvars,";

my @fvarlist = split ',',$fvars;
my @formfields = ();
my $fnd = 0;
foreach my $var (@fvarlist) {
    # individual form file, then orders.conf is in the @fields array.
    # Find the first definition (we want form file's definition over what's
    # in orders.conf)
    
    for (my $i=0; $i < scalar @fields; $i++) {
        my ($fieldname,$fielddesc,$cookie,$type,$length,$comment,$choices,$initval)=split '~',$fields[$i];
        if ($fieldname eq $var) {
            push @formfields,"$fieldname~$fielddesc~$cookie~$type~$length~$comment~$choices~$initval";
            $i = scalar @fields +1;
        }
    }
}

my $numparties;
my $numextracc;
my $numkids;

if ($rpttype ne "") {
    foreach (@formfields) {
        my ($fieldname,$fielddesc,$cookie,$type,$length,$comment,$choices,$initval)=split '~';
        if ($fieldname eq "") {
            next;
        }
        # show fields if it's on the fieldname list for the form,
        # OR if it's mdate, since mdate appears on all forms
        #if ($fieldq=~/,$fieldname,/ or $fieldname eq "mdate") {
        #  12th won't use mdate!  no certificate of service here...
        my $cookval;
        if ($fieldq=~/,$fieldname,/) {
            # support for initval in TEXT field
            if ($type eq "TEXT") {
                if($initval ne "") {
                    if($initval=~/blank/) {
                        $cookval="&nbsp;&nbsp;";
                    } else {
                        $cookval=$initval;
                    }
                }
            }
            
            if ($cookie ne "") {
                $cookval=$info->cookie($cookie);
            } else {
                if ( ! ($type eq "TEXT" and $initval ne "") ) {
                    $cookval="";
                }
            }
            
			if ($type =~ /TEXTAREA/) {
				my ($x, $y) = split(";", $length);
				print qq{<tr><td><b>$fielddesc</b></td>\n<td><textarea name="$fieldname" rows="$y" cols="$x" value="$cookval"></textarea> $comment</td></tr>\n};
            } elsif ($type=~/DATE|TIME|TEXT/) {
                print qq{<tr><td><b>$fielddesc</b></td>\n<td><input name="$fieldname" type="text" size="$length" value="$cookval"> $comment</td></tr>\n};
            } elsif ($type=~/CHECKBOX/) {
                print qq{<tr><td><b>$fielddesc</b></td>\n<td><input name="$fieldname" type="checkbox" value="X"};
                if($initval=~/checked/) {
                    print " checked ";
                }
                print "></td></tr>\n";
            } elsif ($type=~/DROPDOWN/) {
                # get choices and put them in a drop down
                print qq{<tr><td><b>$fielddesc</b></td>\n<td><select name="$fieldname" id="$fieldname"> };
                my @sels = split(':',$choices);
                my $i=0;
                foreach my $val (@sels) {
                    chomp($val);
                    if($i eq 0) {
                        $sel="SELECTED";
                    } else {
                        $sel="";
                    }
                    
                    print qq{<option value="$val" $sel>$val};
                    $i++;
                }
                print "</select> $comment</td></tr>\n";
			} else {
                print "<tr><td>type $type for $fieldname unimplemented</td></tr>\n";
            }
        }
    }
    
    print "</table>";
    
    # if \selectkids is in the FIELDS, put in selection here...
    $numkids=write_kids($caseid,@fields); # special case for selecting kids if, tagged
    
    print <<EOS;
<h3>Send Notices To:</h3>
<table>
EOS

    $numparties=write_parties($case_id,\@fields, $nocheck, $case_id);
    
    # write additional copy list block (/copystart, /copyend)
    $numextracc = write_copylist($caseid,@fields);
    
    if ($showRtfOption) {
        print qq{
            <tr>
                <td>
                    <input type="checkbox" name="genrtf">
                </td>
                <td colspan="2">
                    Generate editable RTF instead of PDF (will not generate copies or envelopes)
                </td>
            </tr>
        };
    }
    
    print qq{
        <tr>
            <td>
                <input type="checkbox" name="pcopies"/>
            </td>
            <td colspan="2">
                Generate Copies (Maximum is $maxcopies copies)
            </td>
        </tr>
        <tr>
            <td>
                <input type="checkbox" name="penvelopes"/>
            </td>
            <td colspan="2">
                Generate Envelopes
            </td>
        </tr>
        <tr>
            <td>
                <input type="checkbox" name="paddresses"/>
            </td>
            <td colspan="2">
                Generate Address List Page
            </td>
        </tr>
    };

	my @esigs;
	
	if (getEsigs(\@esigs, $info->remote_user())) {
		print qq {
			<tr>
				<td>
					<input type="checkbox" name="usees" id="usees" value="1" checked="checked"/>
				</td>
				<td colspan="2">Apply Electronic Signature:&nbsp; &nbsp;
		};
		# User either has a signature in place or is authorized to use others
		print qq {<select id="signAs" name="signAs"><option value="" selected="selected">Please select a signature to apply</option>};
		foreach my $signame (@esigs) {
			my $selected = "";
			if ((scalar(@esigs) == 1) || (lc($signame->{'user_id'}) eq lc ($info->remote_user()))) {
				# There is only 1 possibility, or the user has a sig.  Check that one by default.
				$selected = qq {selected="selected"};
			}
			$signame->{'fullname'} = buildName($signame,1);
			print qq {<option value="$signame->{'user_id'}" $selected>$signame->{'fullname'}</option>\n};
		}
		print qq {</td></tr>\n};
	} 

    
    print <<EOS;
<tr><td>
EOS
}
my $isCircuit = ($caseType =~ /CIRCUIT|FAMILY|JUVENILE|PROBATE/) ? 1:0;

print <<EOS;
</table>
<input type="hidden" name="ucn" value="$ucn"/>
<input type="hidden" name="caseid" value="$caseid"/>
<input type="hidden" name="numparties" value="$numparties"/>
<input type="hidden" name="evtype" value="$EVTYPE"/>
<input type="hidden" name="ttype" value="$ttype"/>
<input type="hidden" name="dbtype" value="$dbtype"/>
<input type="hidden" name="dbname" value="$dbname"/>
<input type="hidden" name="formdesc" value="$FORMDESC"/>
<input type="hidden" name="maxcopies" value="$maxcopies"/>
<input type="hidden" name="numextracc" value="$numextracc"/>
<input type="hidden" name="numkids" value="$numkids"/>
<input type="hidden" name="extendedcaseid" value="$extCaseId"/>
<input type="hidden" name="casetype" value="$caseType"/>
<input type="hidden" name="isCircuit" value = "$isCircuit"/>
<input type="hidden" name="docketDesc" value="$DOCTDESC"/>
<button type="submit" id="genButton" name="submit" style="display: none">Generate</button>
EOS

if (defined($returnAddr)) {
	print qq{<input type="hidden" name="returnAddr" value="$returnAddr"/>\n};
};

if (defined($propAddr)) {
    print qq{<input type="hidden" name="propertyAddress" value="$propAddr"/>\n};
};

print <<EOS;
</form>
EOS




