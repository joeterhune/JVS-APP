#!/usr/bin/perl -w

# scorder.cgi
BEGIN {
	use lib "/usr/local/icms/bin";
}
use strict;

use ICMS;
use CGI;
use CGI::Carp qw(fatalsToBrowser);
use Cwd;
use Orders qw(
    buildReturnAddr
    getExtraParties
	getCaseDiv
	checkSignature
	getEsigs
);
use DB_Functions qw (
	dbConnect
	getData
	getDataOne
	getDbSchema
	findCaseType
	$DEFAULT_SCHEMA
);
use Common qw (
	dumpVar
	inArray
	buildName
);
use Showcase qw (
	$db
);

my $DPATH="/usr/local/icms/cgi-bin/orders/forms";
my $SIGS="/usr/local/icms/cgi-bin/orders/sigs/";
my $FFEXT=".form";
# configurable!  don't allow more than 10 copies to be produced by the
# order generator.
my $maxcopies = 10;

my $dbh = dbConnect($db);
my $schema = getDbSchema($db);

my $nocheck = 0;


#  write active pro se and attorneys for asking for copies
sub write_parties {
    my $casenum = shift;
	my $fieldref = shift;
    my $dbh = shift;
	my $schema = shift;

	if (!defined($schema)) {
		$schema = $DEFAULT_SCHEMA
	};

	my @partyTypeArray = (
		"'DFT'","'PLT'","'PET'","'RESP'","'APNT'","'APLE'","'ATTY'","'ASA'","'PD'","'APD'","'HYBRID'"
	);

    my $hadDb = 1;
    if (!defined($dbh)) {
		$dbh = dbConnect($db);
		$hadDb = 0;
    }

	my $partyTypes = join(",", @partyTypeArray);

    # get active parties
    my $query = qq {
		select
			upper(LastName) as LastName,
			upper(FirstName) as FirstName,
			upper(MiddleName) as MiddleName,
			PartyType,
			PartyTypeDescription,
			PersonID
		from
			$schema.vAllParties
		where
			CaseNumber = ?
			and PartyType in ($partyTypes)
			and Active='Yes'
    };

    my @parties;
	getData(\@parties,$query,$dbh,{valref => [$casenum]});

    my @list;
    # for each pidm, see if there's an atty.  if not, that person is pro se.
    foreach my $party (@parties) {
		my($id,$code,$seq,$assoc)=split '~';
		my $found = 0;
		if($party->{'PartyType'} ne 'ATTY') {
			foreach my $person (@parties) {
				next if ($person->{PersonID} == $party->{PersonID});
				if ($person->{PartyType} eq 'ATTY') {
					$found++;
				}
			}
			if($found eq 0) {
				# didn't find an atty - - so, pro se.  put in list.
				push (@list,$party);
			}
		} else {
			# is an atty
			push (@list,$party);
		}
    }

    get_addresses(\@list,$casenum,$dbh,$schema);

    undef(@parties);

    # for each party in the list, get the address and rebuild the parties list
    foreach my $party (@list) {
		my $fullname;
		if ((!defined($party->{FirstName})) || ($party->{FirstName} eq "")) {
			$fullname = $party->{LastName};
		} else {
			$fullname = sprintf ("%s, %s %s", $party->{LastName},
								 $party->{FirstName}, $party->{MiddleName});
		}
		push @parties,"$fullname~" . $party->{Address};
	}

	# Are there any extra parties (delimited by /extraparties and /endparties)?
	getExtraParties(\@parties,$fieldref);

    # almost done!  add a couple of blank address blocks
    push(@parties,"");
    push(@parties,"");

    my $i=0;
    foreach my $party (@parties) {
		my ($pname,$addr1,$addr2,$city, $state,$zip)=split '~',$party;
		my $checked;
		if (($nocheck) || ($pname eq "")) {
			$checked="";
		} else {
			$checked="checked=\"checked\"";
		}
	print qq {<tr><td><input type=checkbox name=check$i $checked>
	<td><input type="text" name="name$i" value="$pname" size="40">
	<tr><td><td><input type="text" name="addr1$i" value="$addr1" size="40">};
	if ($addr2 ne "") {
	    print qq{<tr><td><td><input type="text" name="addr2$i" value="$addr2" size="40">};
	} else {
		print qq{<tr><td><td><input type="text" name="addr2$i" size="40">};
	}
	if($city eq "" and $state eq "" and $zip eq "") {
	    print qq{<tr><td><td><input type="text" name="csz$i" value=" " size="40"><tr><td>&nbsp;};
	} else {
	    print qq{<tr><td><td><input type="text" name="csz$i" value="$city, $state $zip" size="40"><tr><td>&nbsp;};
	}
	$i++;
    }

    if (!$hadDb) {
		$dbh->disconnect;
    }

    return $i;
}


sub get_addresses {
    my $partyref = shift;
    my $casenum = shift;
    my $dbh = shift;
	my $schema = shift;

	if (!defined($schema)) {
		$schema = $DEFAULT_SCHEMA
	};

    my $hadDb = 1;
    if (!defined($dbh)) {
		$dbh = dbConnect($db);
		$hadDb = 0;
    }

    foreach my $party (@{$partyref}) {
		my $query = qq {
			select
				upper(Address1) as Address1,
				upper(Address2) as Address2,
				upper(City) as City,
				upper(State) as State,
				upper(ZipCode) as ZipCode,
				AddressType
			from
				$schema.vAllPartyAddress with(nolock)
			where
				CaseNumber = ?
				and PartyTypeDescription = ?
				and ((DefaultAddress='Yes') or (DefaultAddress is null))
		};

		my @addresses;
		getData(\@addresses,$query,$dbh,{valref => [$casenum,$party->{'PartyTypeDescription'}]});

		# There should only be 1 returned by the query above.
		my $record = $addresses[0];
		my $address = $record->{Address1};
		if (defined($record->{Address2})) {
			$address .= "~" . $record->{Address2};
		} else {
			$address .= "~";
		}

		$address .= "~" . $record->{City} . "~" . $record->{State} . "~" .
		$record->{ZipCode};
		$party->{Address} = $address;
	}

    if (!$hadDb) {
		# Didn't have one coming in, so destroy the one we made.
		$dbh->disconnect;
    }
}

# write the copy list block (not the same as parties!)
sub write_copylist {
    my $caseid = shift;
	my @fields = @_;

    my @copylist=();
    my $extra;
    my $checked;
    my $found=0;
    for (my $i=0; $i < scalar @fields; $i++) {
		my ($fieldname,$fielddesc,$cookie,$type,$length,$comment,$choices,
			$initval)=split '~',$fields[$i];
		if ($fieldname=~/^\/copystart/) {
			$found++;
			while (!($fieldname=~/^\/copyend/) and $i < scalar @fields) {
				$i++;
				# "extra" is the number of extra lines to put on the form for
				# the copy list (/copyend~5, for example)
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
			# replace all apostrophes with escape apostrophe
			$addr=~s/'/`/g;
			# need to get the division
			my $div = getdiv($caseid,$schema);
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
				$checked="checked=\"checked\"";
			}
			print "<tr><td><input type=checkbox name=eccheck$i $checked> ";
			print "<td><input type=text name=ecaddr$i value='$addr' size=100>";
			$j++;
		}

		# and give extra fill lines
		for ($j=1; $j <= $extra; $j++) {
			print "<tr><td><input type=checkbox name=eccheck$i > ";
			print "<td><input type=text name=ecaddr$i value='' size=100>";
			$i++;
		}
		print "<tr><td>&nbsp;";
		return $i;
	} else {
		return 0;
    }
}

sub getdiv {
    # get the judge name and div from parties list - find the active judge for this case
    my $caseid = shift;
    my $dbh = shift;
	my $schema = shift;

	if (!defined($schema)) {
		$schema = $DEFAULT_SCHEMA;
	};

    my $hadDb = 1;
    if (!defined($dbh)) {
		$dbh =  dbConnect($db);
		$hadDb = 0;
    }

    my $query = qq {
		select
		    DivisionID
		from
		    $schema.vCase
		where
		    CaseNumber = ?
    };

	my $div = getDataOne($query,$dbh,[$caseid]);

    if (!$hadDb) {
		# Didn't have one coming in, so destroy the one we made.
		$dbh->disconnect;
    }

    if (defined($div)) {
		return ($div->{DivisionID});
    } else {
		return undef;
    }
}


#########################################################
#                     MAIN PROGRAM
#########################################################

my $info=new CGI;
my $ucn=$info->param("ucn");  # a given
my $casenum=$ucn;
$casenum=~s#-##g;
my $caseType = findCaseType($ucn);

print $info->header;

my $rpttype=$info->param("rpttype"); # if called from a reload
my $lev=$info->param("lev");

if ($lev eq "") { $lev=5; }
my $prev=$lev-1;

my(%forms,@fields,$thisform);

my $returnAddr = undef;

# look for new .form files
opendir MYDIR, $DPATH;
my @contents = grep !/^\.\.?$/, readdir MYDIR;
closedir MYDIR;

my $nextcgi = "scorder2.cgi";
my $showRtfOption = 0;

my $caseDiv = getCaseDiv($dbh,$ucn,$db,$schema);

foreach my $item (@contents) {
    if ( !(-d $item) and (substr($item, -5) eq $FFEXT) ) {
        open INFILE,"$DPATH/$item" or die "Unable to open file '$DPATH/$item': $!\n\n";
        while (<INFILE>) {
            chomp;
            if (/^#/) {
                next;
            }
            if (/^ORDER/) {
                next;
            }
            if (/^FIELDS/) {
                last;
            }

            my($title,$formfile,$div,$vars,$county,$evtype,$ttype,$cDivs)=split '~';
            if (defined($cDivs)) {
                $cDivs =~ s/\s+//g;
            }

            if (($cDivs =~ /^all$/i) || ($cDivs eq "")) {
                $forms{$formfile}="$title~$div~$vars~$county~$evtype~$ttype~$cDivs";
            } else {
                # Divs were specified
                my @targetDivs = split(/,/, $cDivs);
                if (inArray(\@targetDivs,$caseDiv)) {
                    $forms{$formfile}="$title~$div~$vars~$county~$evtype~$ttype~$cDivs";
                } else {
                    close INFILE;
                    next;
                }
            }

            $thisform=$formfile;
        }

        # when a form is selected, get its form fields.
        if($rpttype eq $thisform){
            while (my $line = <INFILE>) {
                chomp;
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

                if (/^JAS/) {
                    last;
                } # skip JA section--not relevent here
                my ($fieldname,$fielddesc,$cookie,$type,$length,$comment,
                    $choices,$initval)=split ('~',$line);
                push @fields,"$fieldname~$fielddesc~$cookie~$type~$length~$comment~$choices~$initval";
            }
        }
        close(INFILE);
    }
}

#
# then, get the orders.conf file - - that way, we'll have any fields defined in forms first (like we want to!)
#
# (there is no longer support for having forms defined within orders.conf!)
#
open INFILE,"$DPATH/orders.conf" or die "Unable to open input file '$DPATH/orders.conf: $!\n\n";
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


print <<EOS;
<!DOCTYPE html>
<html>
<head>
<title>Generate Form Order</title>

EOS
my $dbtype="";

my $caseid=$ucn;
#$caseid=~ tr/-//d;

print <<EOS;
<title>Create Form Order</title>
<link rel="stylesheet" type="text/css" href="/case/icms1.css">
<script type="text/javascript" src="https://e-services.co.palm-beach.fl.us/cdn/jslib/jquery-1.11.0.js"></script>
<script src="https://e-services.co.palm-beach.fl.us/cdn/jslib/jquery.cookie.js" type="text/javascript"></script>
<script src="/case/icms.js?1.1" type="text/javascript"></script>
<script src="/case/javascript/main.js?1.1" type="text/javascript"></script>
</head>
<body>

	<script type="text/javascript">
		\$(document).ready(function () {
			if ((\$('#rpttype').val() != undefined) && (\$('#rpttype').val() != "")) {
				\$('#genButton').show();
			};
			SetBack('ICMS_$lev');
						
			\$('#genButton').click(function() {
				setAutoSave(theform);
				if(navigator.appName.indexOf("Internet Explorer")!=-1){
					window.external.AutoCompleteSaveForm(theform);
				}
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

		function update(ucn,lev) {
		    box=document.forms[0].rpttype;
		    rpttype=box.options[box.selectedIndex].value;
		    document.location='scorder.cgi?ucn='+ucn+'&lev='+lev+'&rpttype='+rpttype;
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
<tr><td><b>Case #<td>$ucn
<tr><td><b>Form<td><select id="rpttype" name="rpttype" onchange="update('$ucn','$lev')">
<option>
EOS
# was looking for one 'div' per form.  now, it can be several.
my @formlist;
# A copy of $ttype outside of the limited scope.
my $gttype;
foreach my $formfile (keys %forms) {
    my ($title,$div,$vars,$county,$evtype,$ttype)=split '~',$forms{$formfile};
    $gttype = $ttype;
    if("ALL" eq $div){
	push(@formlist,"$title~$formfile~$vars~$county~$evtype~$ttype");
    } else {
	# see if the case number contains any of the listed divisions
	my @divlist = split ',',$div;
	foreach (@divlist) {
	    if($ucn =~/$_/) {
		push(@formlist,"$title~$formfile~$vars~$county~$evtype~$ttype");
	    }
	}
    }
}

@formlist=sort @formlist;
my $sel;
my $fvars;
my $FORMDESC;
my $EVTYPE;

foreach (@formlist) {
    my ($title,$formfile,$vars,$county,$evtype,$ttype)=split '~';
    $gttype = $ttype;
    if ($formfile eq $rpttype) {
	$sel="SELECTED";
	$fvars=$vars;
	$FORMDESC=$title;
	$EVTYPE=$evtype;
    } else {
	$sel="";
    }
    print "<option value=$formfile $sel>$title\n";
}
print "</select>";
my $fieldq=",$fvars,";

my @fvarlist = split ',',$fvars;
my @formfields = ();
my $fnd = 0;
foreach my $var (@fvarlist) {
    # individual form file, then orders.conf is in the @fields array.
    # Find the first definition (we want form file's definition over what's
    # in orders.conf)
    for (my $i=0; $i < scalar @fields; $i++) {
	my ($fieldname,$fielddesc,$cookie,$type,$length,$comment,
	    $choices,$initval)=split '~',$fields[$i];
	if ($fieldname eq $var) {
	    push @formfields,
		"$fieldname~$fielddesc~$cookie~$type~$length~$comment~".
		    "$choices~$initval";
	    $i = scalar @fields +1;
	}
    }
}

my $numparties;
my $numextracc;
my $numkids = 0;
if ($rpttype ne "") {
    foreach (@formfields) {
	my $cookval;
	my ($fieldname,$fielddesc,$cookie,$type,$length,$comment,
	    $choices,$initval)=split '~';
	if ($fieldname eq "") {
	    next;
	}
	# show fields if it's on the fieldname list for the form,
	# OR if it's mdate, since mdate appears on all forms
	#if ($fieldq=~/,$fieldname,/ or $fieldname eq "mdate") {
	#  15th won't use mdate!  no certificate of service here...
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
			print qq {<tr><td><b>$fielddesc</td><td><input name="$fieldname" type="text" } .
				qq {size="$length" value="$cookval"> $comment</td></tr>};
	    } elsif ($type=~/CHECKBOX/) {
			print qq {<tr><td><b>$fielddesc</td><td><input name="$fieldname" } .
				qq {type="checkbox" value="X" };
			if($initval=~/checked/) {
				print qq { checked="checked"};
			}
			print ">";
	    } elsif ($type=~/DROPDOWN/) {
			# get choices and put them in a drop down
			print qq{<tr><td><b>$fielddesc</td><td><select name="$fieldname" id="$fieldname">};
			my @sels = split(':',$choices);
			my $i=0;
			foreach my $val (@sels) {
				chomp($val);
				if($i eq 0) {
					$sel= qq{ selected="selected"};
				} else {
					$sel="";
				}
				print qq{<option value="$val" $sel>$val};
				$i++;
			}
			print "</select> $comment</td></tr>";
		} else {
			print "<tr><td>type $type for $fieldname unimplemented</td></tr>";
		}
	}
}
print "</table>";

# if \selectkids is in the FIELDS, put in selection here...
# Don't need this for Showcase at this time.
#$numkids=write_kids($caseid,@fields); # special case for selecting kids if, tagged

print <<EOS;
<h3>Send Notices To:</h3>
<table>
EOS

$numparties=write_parties($ucn,\@fields,$dbh,$schema);

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
	print qq {<select name="signAs" id="signAs"><option value="" selected="selected">Please select a signature to apply</option>};
	
	foreach my $signame (@esigs) {
		my $selected = "";
		if ((scalar(@esigs) == 1) || (lc($signame->{'user_id'}) eq lc ($info->remote_user()))) {
			# There is only 1 possibility, or the user has a sig.  Check that one by default.
			$selected = qq {selected="selected"};
		}
		$signame->{'fullname'} = buildName($signame,1);
		print qq {<option value="$signame->{'user_id'}" $selected>$signame->{'fullname'}</option>\n};
	}
	print qq {</select></td></tr>\n};
}
	
print <<EOS;
<tr><td>
EOS
}

my $isCircuit = ($caseType =~ /CIRCUIT/) ? 1:0;

print <<EOS;
</table>
<input type="hidden" name="ucn" value="$ucn">
<input type="hidden" name="caseid" value="$caseid">
<input type="hidden" name="numparties" value="$numparties">
<input type="hidden" name="evtype" value="$EVTYPE">
<input type="hidden" name="ttype" value="$gttype">
<input type="hidden" name="dbtype" value="$dbtype">
<input type="hidden" name="dbname" value="$db">
<input type="hidden" name="formdesc" value="$FORMDESC">
<input type="hidden" name="maxcopies" value="$maxcopies">
<input type="hidden" name="numextracc" value="$numextracc">
<input type="hidden" name="numkids" value="$numkids">
<input type="hidden" name="extendedcaseid" value="$caseid">
<input type="hidden" name="casetype" value="$caseType">
<input type="hidden" name="isCircuit" value = "$isCircuit">
<button type="submit" id="genButton" name="submit" style="display: none">Generate</button>
EOS

if (defined($returnAddr)) {
	print "<input type=\"hidden\" name=\"returnAddr\" value=\"$returnAddr\">"
};

print <<EOS;
</form>
</font>
EOS
