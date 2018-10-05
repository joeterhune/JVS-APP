#!/usr/bin/perl -w

# search.cgi - performs unified searches on both Banner and Showcase

# Pulls Criminal cases from Showcase, all other cases from Banner.  Should
# be relatively easy to move court types between databases by manipulating the
# appropriate arrays

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;
use CGI qw(:standard);
use ICMS;
use Common qw (
    inArray
    dumpVar
    doTemplate
    $templateDir
    ISO_date
	stripWhiteSpace
	sanitizeCaseNumber
	logToFile
    returnJson
    createTab
    getUser
    getSession
    checkLoggedIn
);
use PBSO;
use File::Temp;
use File::Basename;
use Showcase qw(
    showcaseSearch
    citationSearch
    getScCaseInfo
    showcaseCivilSearch
    getScCivilCaseInfo
    showcaseNameSearch
);
use CGI::Carp qw(fatalsToBrowser);
use DB_Functions qw (
    dbConnect
    getData
    inGroup
    ldapConnect
    getQueueItems
    getSubscribedQueues
	getSharedQueues
	getQueues
);
use XML::Simple;
use JSON;
use HTML::Entities;
use URI::Escape;
use Data::UUID;
use Data::Dumper qw(Dumper);

checkLoggedIn();

# Use this to specify the order of the headers in a generated spreadsheet
my @exportHeaders = (
					{
						'Column' => 'Open Warrant?',
						'XMLField' => 'OpenWarrants'
					},
					{
						'Column' => 'Name',
						'XMLField' => 'Name'
					},
					{
						'Column' => 'DOB',
						'XMLField' => 'DOB'
					},
					{
						'Column' => 'Age',
						'XMLField' => 'AGE'
					},
					{
						'Column' => 'Party Type',
						'XMLField' => 'PartyTypeDescription'
					},
					{
						'Column' => 'Case Number',
						'XMLField' => 'CaseNumber'
					},
					{
						'Column' => 'File Date',
						'XMLField' => 'FileDate'
					},
					{
						'Column' => 'Last Activity',
						'XMLField' => 'LACTIVITY'
					},
					{
						'Column' => 'Division',
						'XMLField' => 'DivisionID'
					},
					{
						'Column' => 'Type',
						'XMLField' => 'CaseType'
					},
					{
						'Column' => 'Status',
						'XMLField' => 'CaseStatus'
					}
);

my $info = new CGI;

my %params = $info->Vars;

my %result;

my %data;

my $logStr = sprintf("User '%s' looked up '%s' from IP Address '%s'\n", getUser(), $params{'name'}, $ENV{'REMOTE_ADDR'});
logToFile($logStr, "/tmp/lookups.log");

# Can we get a case number out of what was entered?  If so, we can short-circuit
# the rest of this.
my $sanitizedCase = sanitizeCaseNumber($params{'name'});

my $json = JSON->new->allow_nonref;

if (defined($params{'tmpfile'})) {
	my $xs = XML::Simple->new();
	my $ref = $xs->XMLin($params{'tmpfile'});
	foreach my $key (keys %{$ref->{'otherInfo'}}) {
		$ref->{$key} = $ref->{'otherInfo'}->{$key};
	}
	$ref->{'tmpfile'} = $params{'tmpfile'};
	print $info->header();
	doTemplate($ref, "$templateDir/caselists", "searchResults.tt", 0);
	exit;
} else {
	$data{'noTmp'} = 1;
}


# Various fields that were passed by the form or will be easier to pass between
# multiple functions/searches
my %fields;

# Is this user in the SECRET group - able to see adoptions, termination of
# parental rights, and tuberculosis cases?
my $icmsuser = getUser();

my $ldap = ldapConnect();
$fields{'secretuser'} = inGroup($icmsuser,'CAD-ICMS-SEC',$ldap);
$fields{'sealeduser'} = inGroup($icmsuser,'CAD-ICMS-SEALED',$ldap);
$fields{'jsealeduser'} = inGroup($icmsuser,'CAD-ICMS-SEALED-JUV',$ldap);
$fields{'psealeduser'} = inGroup($icmsuser,'CAD-ICMS-SEALED-PROBATE',$ldap);

# Gather other items from the form
foreach my $field ("name","citation","type") {
    if (defined($info->param($field))) {
        $fields{$field} = $info->param($field);
        # For names with single quotes in them.
        $fields{$field} =~ s/\'/\'\'/g;
    }
}

$fields{'fuzzyDOB'} = $params{'fuzzyDOB'};

foreach my $param ('DOB','searchStart','searchEnd') {
	if ((defined($params{$param})) && ($params{$param} ne "")) {
        $params{$param} = uri_unescape($params{$param});
		$params{$param} = ISO_date(stripWhiteSpace($params{$param}));
		$fields{$param} = $params{$param};
		$data{$param} = $params{$param};
	}
}

$data{'lev'} = 2;

foreach my $checkbox ("active","soundex","business","photos","charges", "criminal","nocriminal") {
    if (defined($info->param($checkbox))) {
        $fields{$checkbox} = $info->param($checkbox);
        if ($fields{$checkbox} eq 'true') {
            $fields{$checkbox} = 1;
        }
    } else {
        $fields{$checkbox} = 0;
    }
}

if ((defined($info->param('limitdiv'))) && ($info->param('limitdiv') ne 'All')) {
    my @temp = $info->param('limitdiv');
    $fields{'limitdiv'} = [];    
    foreach my $div (@temp) {
        push(@{$fields{'limitdiv'}}, "'$div'");
    }
}

if ((defined($params{'chargetype'})) && ($params{'chargetype'} ne 'All')) {
    my @temp = $info->param('chargetype');
    $fields{'chargetype'} = [];    
    foreach my $chapter (@temp) {
        push(@{$fields{'chargetype'}}, $chapter);
    }
}

if ((defined($params{'causetype'})) && ($params{'causetype'} ne 'All')) {
    my @temp = $info->param('causetype');
    $fields{'causetype'} = [];    
    foreach my $cause (@temp) {
        # There can be more than 1 case type per cause; split it at commas and quote them before adding to array
        my @casetypes = split(",", $cause);
        foreach my $casetype (@casetypes) {
            push(@{$fields{'causetype'}}, "'$casetype'");
        }
    }
}

if ((defined($info->param('limittype'))) && ($info->param('limittype') ne 'All')) {
    # Get all of the divisions that match this court type
    my $ddbh = dbConnect("judge-divs");
    
    my @temptype = $info->param('limittype');
    
    my @types;
    foreach my $type (@temptype) {
        if ($type eq 'Traffic') {
            push(@types,"'Misdemeanor'");
        }
        push(@types, "'$type'");
    }
    my $inString = join(",", @types);
    
    my $query;
    my @temp;
    $query = qq {
        select
            division_id
        from
            divisions
        where
            division_type in ($inString)
    };
    getData(\@temp, $query, $ddbh);
    
    $fields{'limitdiv'} = [];
    $fields{'limittype'} = $info->param('limittype');
    foreach my $rec (@temp) {
        push(@{$fields{'limitdiv'}}, "'$rec->{division_id}'");
    }
}

# If we're just using criminal, set this value for later printing.
if ($fields{'criminal'} == 1) {
    $fields{'tellcrim'} = " Criminal and Traffic ";
} elsif ($fields{'nocriminal'} == 1) {
    $fields{'tellcrim'} = " Civil ";
}

$fields{'partyTypeLimit'} = [];
if (defined($params{'partyTypeLimit'})) {
    my @temp = $info->param('partyTypeLimit');
    # Gotta quote them
    foreach my $pt (@temp) {
        if ($pt ne 'All') {
            push(@{$fields{'partyTypeLimit'}},"'$pt'");
        }
    }
}

# Populates the "searchmask} element, which is a bitmask showing what needs
# to be used building the queries.
findSearchType (\%fields);

my @cases;

if ($fields{'citationsearch'}) {
    my $casenum = citationSearch($fields{'citation'},\@cases);
    if (scalar(@cases)) {
        if (scalar(@cases) == 1) {
            # A citation search will always yield Showcase cases
            my $outUCN = $cases[0]->{'CaseNumber'};
            my $caseID = $cases[0]->{'CaseID'};
            my $output = getScCaseInfo($outUCN, $caseID);
            my %result;
            print $info->header();
            print $output;
            exit;
        } else {
            # Found multiple matches for the wildcard
            my %citationFields = (
                                  'dtitle' => "Citation",
                                  'name' => $fields{'citation'},
                                  'reportheaders' => 'Citation~Case #~Description~File Date~Last Activity~Division~Type~Status',
                                  'reportformat' => 'A~L~I~D~D~A~S~A',
                                  'reporttype' => 'citation',
                                  'viewer' => 'view.cgi'
            );
            my $tmpfile = "/tmp/" . writeTempFile(\%citationFields,\@cases);
            print $info->redirect("/case/genlist.php?rpath=$tmpfile&lev=2");
            exit;
        }
    } else {
        print $info->header();
        print "There were no cases found for citation '$fields{citation}'<br/>";
        exit;
    }
} else {
    # OK, if we're here, it's not a citation search.
    
    print $info->header();
    
    if (sanitizeCaseNumber($fields{'name'}) eq "") {
        showcaseNameSearch(\%fields, \@cases);
    } else {
        if($fields{'criminal'} != 1) {
            showcaseCivilSearch(\%fields, \@cases);
        }
        if($fields{'nocriminal'} != 1) {
            showcaseSearch(\%fields, \@cases);
        }
    }
    exit;
}


# Ok, we should now have the information on from both databases, in a unified
# kind of format.  Create the output file and then call genlist.php.

if (scalar(@cases) == 1) {
    my $outUCN = $cases[0]->{'CaseNumber'};
    my $output;
    
    if ($outUCN =~ /CA|DR|GA|CP|CC|SC|DP|CJ/) {
        $output = getScCivilCaseInfo($outUCN, $cases[0]->{'CaseID'});
    } else {
        $output = getScCaseInfo($outUCN, $cases[0]->{'CaseID'});
    }
    
    my %result;   
    print $info->header; 
    print $output;
    exit;
}

$data{'limitdiv'} = '';
if (defined($fields{'limitdiv'})) {
    $data{'limitdiv'} = " (Division ". join(",", @{$fields{'limitdiv'}}) . ") ";
}

if (defined($fields{'limittype'})) {
    $data{'limitdiv'} = sprintf(" (%s only) ", $fields{'limittype'});
}

$data{'DOBstr'} = '';
if ((defined($params{'inDOB'})) && ($params{'inDOB'} ne "")) {
	$data{'DOBstr'} = sprintf (" (DOB %s) ", $params{'inDOB'});
}

$data{'dTitle'} = sprintf ("%s Search %s for %s %s - ", $fields{'dtitle'}, $data{'limitdiv'},
						   $fields{'name'}, $data{'DOBstr'});

# Strip the viewer from the case number; we don't need it any more.
foreach my $case (@cases) {
    $case->{'CaseNumber'} = (split(";",$case->{'CaseNumber'}))[0];
}

# We still need to write the file, as it will be handy in case of an export.
$data{'cases'} = \@cases;

$data{'tmpfile'} = writeXmlFile(\%data, \@exportHeaders);
if (defined($params{'photos'})) {
	$data{'photos'} = 1;
}
if ($fields{'hadCharges'}) {
	$data{'charges'} = 1;
}

# Generate a unique division ID.
my $ug = Data::UUID->new;
my $uuid = $ug->create();
$data{'searchID'} = sprintf("search-%s", $ug->to_string($uuid));

my $idbh = dbConnect("icms");
#$info = new CGI;
my $user = getUser();

createTab("Search Results", "/cgi-bin/case/search.cgi?name=" . $fields{'name'}, 1, 1, "index");
my @myqueues = ($user);
my @sharedqueues;
my $session = getSession();
			
getSubscribedQueues($user, $idbh, \@myqueues);
getSharedQueues($user, $idbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;
			
my $wfcount = getQueues(\%queueItems, \@allqueues, $idbh);
$data{'wfCount'} = $wfcount;
$data{'active'} = "index";
$data{'tabs'} = $session->get('tabs');

print $info->header;
doTemplate(\%data, "$templateDir/top", "header.tt", 1);
doTemplate(\%data, "$templateDir/caselists", "searchResults.tt", 1);
exit;


sub writeXmlFile {
    my $data = shift;
	my $exportHeaders = shift;
    
    my $otherInfo = {
        "dTitle" => $data->{'dTitle'},
        "name" => $data->{'name'}
    };
    if ($data->{'limitdiv'} ne "") {
        $otherInfo->{'limitdiv'} = $data->{'limitdiv'};
    }
	if ((defined($data->{'DOB'})) && ($data->{'DOB'} ne "")) {
		$otherInfo->{'DOB'} = $data->{'DOB'};
	}
	
    my $fh = File::Temp->new (
                              UNLINK => 0,
                              DIR => "/tmp",
                              SUFFIX => '.xml'
    );
    my $filename = $fh->filename;
    # We only needed a unique name, so close the file.
    close ($fh);
    
    my $xs = XML::Simple->new(
        XMLDecl => 1,
		NoAttr => 1,
        KeepRoot => 1,
        RootName => 'SearchResult',
        OutputFile => $filename
    );
    
    my $xml = $xs->XMLout({cases => $data->{'cases'},
                           otherInfo => $otherInfo,
                           exportHeaders => $exportHeaders} );
    
    return $filename;
}


sub findSearchType {
    # Does the work of determining the search type, as indicated from the
    # input data.
    my $fieldref = shift;

    # Sanitize the input a little bit
    foreach my $field ("name","citation") {
        if (defined ($fieldref->{$field})) {
            if (defined($fieldref->{$field})) {
                # Remove leading and trailing whitespace from the name
                $fieldref->{$field} =~ s/^\s+//g;
                $fieldref->{$field} =~ s/\s+$//g;
                # Compress whitespace
                $fieldref->{$field} =~ s/\s+/ /g;
                # And translate to uppercase
                $fieldref->{$field} = uc($fieldref->{$field});
            }
        }
    }

    $fieldref->{'dtitle'} = "";
    $fieldref->{'dtitle2'} = "";

    # Just in case the user didn't press the appropriate search button...
    if ((!defined($fieldref->{'type'})) || ($fieldref->{'type'} eq "")) {
        if (($fieldref->{'name'} eq "") && ($fieldref->{'citation'} eq "")) {
        	my $info = new CGI;
            print $info->redirect(-uri => "/case/");
            exit;
        }
    }

    if ((defined($fieldref->{'citation'})) && ($fieldref->{'citation'} ne "")) {
	$fieldref->{'citationsearch'} = 1;
    } elsif ($fieldref->{'name'} ne "") {
	# It's a name search of some sort
	if ($fieldref->{'name'} =~ /^[A-Z,*]/) {
	    $fieldref->{'namesearch'} = 1;
	}

	if ($fieldref->{'business'} == 1) {
	    # Business name search
	    $fieldref->{'nametype'} = "last";
	    $fieldref->{'dtitle'} = "Business";
	} elsif (($fieldref->{'name'}=~/,/) ||
		 ($fieldref->{'name'}=~/ /)) {
	    # Not a business name, and has space or comma.
	    $fieldref->{'nametype'} = "firstandlast";
	    $fieldref->{'dtitle'} = "Individual";
	} else {
	    # Just a last name
	    $fieldref->{'nametype'} = "last";
	    $fieldref->{'dtitle'} = "Individual";
	}
    
    if (scalar(@{$fieldref->{'partyTypeLimit'}})) {
        $fieldref->{'searchtype'} = "others";
    } else {
        $fieldref->{'searchtype'} = "regular";
    }

	if ($fieldref->{'soundex'} == 1) {
	    $fieldref->{'dtitle'} .= " Sounds Like ";
	}

	$fieldref->{'dtitle'} .= " Name ";


	# Start picking the name apart
	if ($fieldref->{'nametype'} eq 'firstandlast') {
	    if ($fieldref->{'name'} =~ /,/) {
			# We found a comma, so it's in the format last, first
			($fieldref->{'last'}, $fieldref->{'first'}) =
			    split(',', $fieldref->{'name'},2);
			$fieldref->{'first'} =~ s/^\s+//g;
			
			if ($fieldref->{'first'} =~ /\s+/) {
				($fieldref->{'first'}, $fieldref->{'middle'}) =
			    split(" ", $fieldref->{'first'}, 2);
			}
	    } elsif ($fieldref->{'name'} =~ /\s+/) {
			# We have a space but no comma.  Format is first last
			($fieldref->{'first'}, $fieldref->{'last'}) =
			    split(" ", $fieldref->{'name'}, 2);
			    
			if ($fieldref->{'last'} =~ /\s+/) {
				($fieldref->{'middle'}, $fieldref->{'last'}) =
			    split(" ", $fieldref->{'last'}, 2);
			}
	    }

	    if (index($fieldref->{'last'},'*') != -1) {
		$fieldref->{'last2'} = substr($fieldref->{'last'},0,
					      index($fieldref->{'last'},'*'));

	    }
	} else {
        # Just a last name or business name
        if (index($fieldref->{'name'},'*') != -1) {
            $fieldref->{'name2'} = substr($fieldref->{'name'},0,
                                          index($fieldref->{'name'},'*'));
            if (length($fieldref->{'name2'}) < 1) {
                print qq {You must enter 1 or more letters when doing a wildcard search on just the last name or a business name.<br/>Please try again...};
                exit;
            }
        }
    }
    }
    
    if ($fieldref->{'charges'} == 1 || ($fieldref->{'charges'} eq "on")) {
        if ($fieldref->{'name'} =~/(\d+)(\D+)(\d+)(\D){0,1}/) {
            $fieldref->{'reporttype'} = "singlecasewithcharges";
        } else {
            $fieldref->{'reporttype'} = "multicasewithcharges";
        }
    } elsif ($fieldref->{'name'}=~/(\d+)(\D+)(\d+)(\D){0,1}/) {
        $fieldref->{'reporttype'} = "singlecasenocharges";
    } else {
        $fieldref->{'reporttype'} = "multicasenocharges";
    }
    
    $fieldref->{'reportheaders'} = $reportHeaders{$fieldref->{'reporttype'}};
    $fieldref->{'reportformat'} = $formats{$fieldref->{'reporttype'}};
}
