#!/usr/bin/perl -w

# merge.cgi - merges the .tt form with JSON data, creating an html document for viewing/editing/printing
BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
}

use CGI;
use Template;
use JSON;
use File::Slurp qw(read_file write_file);
use Data::Dumper;
use DateTime;
use DateTime::Format::DateParse;
use DB_Functions qw (
    dbConnect
    getData
    getDataOne
);
use Common qw (
    dumpVar
    returnJson
    inArray
);

use MIME::Base64;
use URI::Escape;
use HTML::Entities;
use strict;

# pretty_order_date takes an MM/DD/YYYY and returns dates like "Monday, December 2, 2013".

sub pretty_order_date {
    my $indate = shift;
    my $dt=DateTime::Format::DateParse->parse_datetime($indate);
    # leaving of %A (day of week) since there's a field for that.
    my $outdate=$dt->strftime('%B %e, %Y');
    return $outdate;
}

sub getMagistrateRoom {
	my $magistrate = shift;
	my @mag_name = split / /, $magistrate;
	my $name_length = scalar(@mag_name);
	my $first = $mag_name[0];
	my $last = $mag_name[$name_length - 1];

	my $dbh = dbConnect("judge-divs");

	my $query = qq {
		select
			SUBSTRING_INDEX(hearing_room, '/', -1) as hearing_room
		from
			magistrates
		where
			first_name = ?
			and last_name = ?
	};
	my $mag = getDataOne($query, $dbh, [uc($first), uc($last)]);

	return $mag->{'hearing_room'};
}

sub getMagistrateAddress {
	my $magistrate = shift;
	my @mag_name = split / /, $magistrate;
	my $name_length = scalar(@mag_name);
	my $first = $mag_name[0];
	my $last = $mag_name[$name_length - 1];

	my $dbh = dbConnect("judge-divs");

	my $query = qq {
		select
			address
		from
			magistrates
		where
			first_name = ?
			and last_name = ?
	};
	my $mag = getDataOne($query, $dbh, [uc($first), uc($last)]);

	return $mag->{'address'};
}

sub getMediationAddress {
	my $room = shift;

	my $dbh = dbConnect("ols");

	my $query = qq {
		select
			partial_address
		from
			mediation_scheduling.locations
		where
			room_number = ?
	};
	
	my $med = getDataOne($query, $dbh, [$room]);

	return $med->{'partial_address'};
}

sub getFinalDispoStamp{
	my $stampType = shift;
	my $raw_string;
	my $image;
    
    my @stampTypes = (
        "Dismissed After Hearing", "Dismissed Before Hearing", "Dismissed By Default",
        "Disposed by Judge", "Disposed by Non-Jury Trial", "Disposed by Jury Trial"
    );
    
    if (inArray(\@stampTypes, $stampType)) {
        my $imgfile = lc($stampType);
        $imgfile =~ s/\s+/-/g;
        open(IMAGE, "$ENV{'JVS_DOCROOT'}/images/$imgfile") or die "$!";
        $raw_string = do{ local $/ = undef; <IMAGE>; };        
        $image = encode_base64($raw_string);
    } else {
    	$image = "";
    }
	
	return '<img src="data:image/jpeg;base64,' . $image . '"/>';
}

sub calculateTRDueDate{
	my $days = shift;
	
	my $dt = DateTime->now;
	$dt->add(days => $days);
	my $indate = $dt->mdy('/');
	$dt = DateTime::Format::DateParse->parse_datetime($indate);
	
    my $outdate=$dt->strftime('%B %e, %Y');
    return $outdate;
}

#
# MAIN PROGRAM
#
my $info=new CGI;

my $json=JSON->new->allow_nonref;

my %params = $info->Vars;

my ($formdata,@params,$cclist);

my $encode = 0;
if($info->param('encode') eq '1'){
	$encode = 1;
}

if ($info->param('formjson')) { # json object being passed
    my %partyTypes = (
        'PLT' => 'plaintiff',
        'DFT' => 'defendant',
        'PET' => 'petitioner',
        'RESP' => 'respondent',
		'APNT' => 'appellant',
		'APLE' => 'appellee'
    );
    
    $formdata=$json->decode(uri_unescape($info->param('formjson')));
    
    if(defined($formdata->{'ADAText'})){
    	$formdata->{'ADAText'} = decode_base64($formdata->{'ADAText'});
    }
    
    if(defined($formdata->{'ADAText_short'})){
    	$formdata->{'ADAText_short'} = decode_base64($formdata->{'ADAText_short'});
    }
    
    if(defined($formdata->{'InterpreterText'})){
    	$formdata->{'InterpreterText'} = decode_base64($formdata->{'InterpreterText'});
    }
    
    if(defined($formdata->{'TranslatorText'})){
    	$formdata->{'TranslatorText'} = decode_base64($formdata->{'TranslatorText'});
    }
    
    if(defined($formdata->{'GMvacate_text'})){
    	$formdata->{'GMvacate_text'} = decode_base64($formdata->{'GMvacate_text'});
    }
    
    if(defined($formdata->{'FileExp_text'})){
    	$formdata->{'FileExp_text'} = decode_base64($formdata->{'FileExp_text'});
    }
	
    my %result;
    
    if ($info->param('cclist') ne "" && ($info->param('cclist') ne 'undefined')) {
        $cclist = $json->decode(uri_unescape($info->param('cclist')));
    }
    
    # Built the parties and party strings.
    foreach my $ptype (keys %partyTypes) {
        $formdata->{$ptype} = [];
        foreach my $party (@{$cclist->{'Parties'}}) {
        	if(defined($party->{'PartyType'})){
	            if ($party->{'PartyType'} eq $ptype) {
	                push(@{$formdata->{$ptype}}, $party->{'FullName'});
	            }
            }
        }
    }
        
    # Now that the list is built, go through the partyTypes list again and build strings
    foreach my $ptype (keys %partyTypes) {
        $formdata->{$partyTypes{$ptype}} = join(",", @{$formdata->{$ptype}});
    }
    
    $formdata->{'case_caption'} = uri_unescape($info->param('case_caption'));
    $formdata->{'case_caption'} =~ s/\t/&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;/g;
    
    if(defined($formdata->{'docket_line_text'})){
	    if($formdata->{'docket_line_text'} eq "FCM General Magistrate Disposition Form" || 
	    	($formdata->{'docket_line_text'} eq "FCM Notice of Assignment to General Magistrate")){
	    	$formdata->{'case_caption'} =~ s/Plaintiff\/Petitioner/$formdata->{'petTitle'}/;
	    	$formdata->{'case_caption'} =~ s/Defendant\/Respondent/$formdata->{'respTitle'}/;
	    }
    }
    
    if(defined($formdata->{'magistrate'})){
    	$formdata->{'magistrateRoom'} = getMagistrateRoom($formdata->{'magistrate'});
    	$formdata->{'GM_address'} = getMagistrateAddress($formdata->{'magistrate'});
    }
    
    if(defined($formdata->{'dddays'})){
    	$formdata->{'tr_due_date'} = calculateTRDueDate($formdata->{'dddays'});
    }
    
    if(defined($formdata->{'mediatorroom_select'})){
    	$formdata->{'mediation_address'} = getMediationAddress($formdata->{'mediatorroom_select'});
    }
    
    if(defined($formdata->{'FinalDispoMeans'})){
    	$formdata->{'FinalDispoStamp'} = getFinalDispoStamp($formdata->{'FinalDispoMeans'});
    }
    
    foreach my $key (keys %{$formdata}) {
        my $val=$formdata->{$key};
        if ($key eq "case_caption") {
            $val=~s/\n/<br>/g;
            #$val=~s/ /&nbsp;/g;
            $val=~s/<br>$//;
            #$val="$val<hr style=\"text-align:left;padding:0px\" width='50%'>";
            $val = $val . "<br/>________________________________________/" . "<br/>";
        }
        
        if (($key=~/date/ || ($key=~/Date/)) && $val=~m#(\d+/\d+/\d+)#) {
        	if($key !~ /unformatted/){
            	$val=pretty_order_date($val);
            }
            else{
            	my $dt = DateTime::Format::DateParse->parse_datetime($val);
			    $val = $dt->strftime('%H:%M:%S %d:%m:%Y');
            }
        }
        if ($val eq "" and ($key ne "order_html")) {
            #$val="[% $key %]";
			#removed line above because it was not recognizing it to be a blank variable and was displaying it if it were null.
			$val="";
        }
        $formdata->{$key}=$val;
    }
} elsif ($info->param('paramfile')) {
    open INFILE,$info->param('paramfile');
    while (<INFILE>) {
        chomp;
        push @params,$_;
    }
    
    close INFILE;
    foreach my $param (@params) {
        my ($key,$val)=split '=',$param,2;
        #if ($key=~/signature/) {
        #    #$val=~s#src=#src=/var/www/html#;
        #}
        if ($key=~/date/ && $val=~m#(\d+/\d+/\d+)#) {
            $val=pretty_order_date($val);
        }
        if ($key eq "case_caption") {
            $val=~s/\\n/<br>/g;  # from mail
            $val=~s/\n/<br>/g;  # from view
            $val=~s/ /&nbsp;/g;
            $val=~s/<br>$//;
            #$val="$val<hr style=\"text-align:left;padding:0px\" width='50%'>";
            $val = $val . "<br/>________________________________________/" . "<br/>";
        }
        if ($key eq "cc_list") {
            $val=~s/\n/\\n/g;
            $val=~s/\r//g;
            $val=$json->decode($val);
        }
        if ($val eq "" and ($key ne "order_html")) {
            $formdata->{$key}="[% $key %]";
        }
        $formdata->{$key}=$val;
    }
} else {
    foreach my $key (sort $info->param()) {
        my $val=$info->param($key);
        my $strt=substr($val,0,1);
        if ($key eq "case_caption") {
            $val=~s/\n/<br>/g;
            $val=~s/ /&nbsp;/g;
            #$val="$val<hr style=\"text-align:left\" width='50%'>";
            $val = $val . "<br/>________________________________________/" . "<br/>";
        }
        if ($key=~/date/ && $val=~m#(\d+/\d+/\d+)#) {
            $val=pretty_order_date($val);
        }
        if ($key eq "cc_list") {
            $val=~s/\n/\\n/g;
            $val=~s/\r//g;
            $val=$json->decode($val);
        }
        if ($val eq "" and ($key ne "order_html")) {
            $formdata->{$key}="[% $key %]";
        } else {
            $formdata->{$key}=$val;
        }
    }
}

#
# turn cc_list from an array to something that TT can use easily.
#


$formdata->{'cc_list'} = "";

if ((defined($cclist->{'Attorneys'}) && (scalar(@{$cclist->{'Attorneys'}}))) || (defined($cclist->{'Parties'}) && (scalar(@{$cclist->{'Parties'}})))) {
    $formdata->{'cc_list'} = '<span style="font-weight: bold;">COPIES TO:</span><br/><table id="cc_list_table" style="border: none; table-layout: fixed; max-width:6.5in;">';
    foreach my $key (keys %{$cclist}) {
        foreach my $party (@{$cclist->{$key}}) {
            next if (!$party->{'check'});
            my $name = $party->{'FullName'};
            my $address = $party->{'FullAddress'};
            
            if ($address eq "") {
                $address = "No Address Available";
            }
            else{
            	$address =~ s/\n/\<br\/\>/g;
            }
            my $svcList;
            if ($party->{'ServiceList'} eq "" || !defined($party->{'ServiceList'})) {
                $svcList = "No E-mail Address Available";
            } 
            elsif(ref($party->{'ServiceList'}) eq "ARRAY"){
            	if(!@{$party->{'ServiceList'}}){
            		$svcList = "No E-mail Address Available";
            	}
            	else{
            		$svcList = join("<br>", @{$party->{'ServiceList'}});
            		$svcList =~ s/;/<br>/g;
            	}
            }
            elsif(ref($party->{'ServiceList'}) eq "HASH"){
            	if(!%{$party->{'ServiceList'}}){	
            		$svcList = "No E-mail Address Available";
            	}
            	else{
	            	foreach my $key (keys %{$party->{'ServiceList'}}) {
	            		$svcList = join("<br>", $party->{'ServiceList'}->{$key});
	            	}
            	}
            }
            else{
            	if($party->{'ServiceList'} eq ""){
            		$svcList = "No E-mail Address Available";
            	}
            	else{
            		$svcList = $party->{'ServiceList'};
            		$svcList =~ s/;/<br>/g;
            	}
            }
            
            my $string = sprintf('<tr><td style="vertical-align:top; word-wrap:break-word; max-width:2.16in;">%s</td><td style="vertical-align:top; word-wrap:break-word; max-width:2.16in;">%s</td><td style="vertical-align:top; word-wrap:break-word; max-width:2.16in;">%s</td></tr>', $name, $address, $svcList);
            $formdata->{'cc_list'} .= $string;
        }
    }
}

$formdata->{'cc_list'} .= "</table>";


# one last thing; the pagebreak field is always the same
$formdata->{pagebreak}="[% pagebreak %]";
#
# now do the merge...
#
my $dbh = dbConnect("icms");
my %result;
my $formbody=$formdata->{order_html}; # see if it's stored here.
if ($formbody eq "") { # nope, pull from forms table...
    my $fid=$formdata->{'form_id'};
    if ($fid eq "") {
        $result{'status'} = "Failure";
        $result{'html'} = "Error: no form_id specified!";
        returnJson(\%result);
        exit;
    }
    
    my $query = qq {
        select
            form_body
        from
            forms
        where
            form_id = ?
    };
    my $temp = getDataOne($query, $dbh, [$fid]);
    $formbody = $temp->{'form_body'};
    
    #($formbody)=sql_list_one($dbh,"select form_body from forms where form_id=$fid");
} else {
    $formbody=uri_unescape($formbody); 
}

if (defined($params{'sigdiv'})) {
    $formdata->{'judge_signature'} = $params{'sigdiv'};
}
else{
	$formdata->{'judge_signature'} = "[% judge_signature %]";
}

# Trying to figure out when to use these...
if($encode eq '1'){
	decode_entities($formbody);
	$formbody = encode_entities($formbody);
}

my $htmldata;

my $tt=Template->new();
if (!$tt->process(\$formbody,$formdata,\$htmldata)) {
    $result{'html'} = $tt->error();
    #print "ERROR:", $tt->error(),"\n";
    #exit(1);
} else {
    $result{'html'} = $htmldata;
}

$result{'success'} = "Success";
returnJson(\%result);
