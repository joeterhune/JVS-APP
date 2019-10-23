#!/usr/bin/perl

BEGIN {
	use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;
use CGI qw (
	fatalsToBrowser
);
use Common qw(
	doTemplate
	dumpVar
	getArrayPieces
	$templateDir
	prettifyString
    inArray
    returnJson
);

use DB_Functions qw (
	dbConnect
	getData
	getDataOne
);

use Export_Utils qw (
	makeSpreadsheet
);

use JSON;

use File::Basename;

my $info = new CGI;

my %params = $info->Vars;

my $startDate;
if (defined($params{'startDate'})) {
	$startDate = $params{'startDate'};
} else {
	$startDate = "1970-01-01";
}

my $endDate;
if (defined($params{'endDate'})) {
	$endDate = $params{'endDate'};
} else {
	my @now = localtime(time);
	$endDate = sprintf("%04d-%02d-%02d", $now[5]+1900, $now[4]+1, $now[3]);
}

my @divisions = split(",", $params{'division'});
#my $division = $params{'division'};
my $division = join ', ', map { qq /'$_'/ } @divisions;
my $flagTypes = $params{'flagTypes'};
my $active = $params{'active'};

my @flagTypeArr = split(",", $flagTypes);

my $icmsconn = dbConnect("icms");

# First, get a listing of all of the cases from the flags DB.
my $query = qq {
	select
		distinct(casenum) as "CaseNumber"
	from
		flags
	where
		date >= '$startDate'
		and date <= '$endDate'
};

if ($flagTypes ne 'all') {
	$query .= qq {
		and flagtype in ($flagTypes)
	};
}

if ($division ne "'all'") {
	$query .= qq {
		and REPLACE(division, '\\0FH', '') IN ($division)
	};
} else {
	$division = "All";
}

$query .= qq {
	order by
		casenum
};

my @cases;
getData(\@cases, $query, $icmsconn);

# And put just the case numbers into an array.
my @justcases;
foreach my $case (@cases) {
	push(@justcases, $case->{'CaseNumber'});
}

# Ok, now we know which cases we want.  Look up the information in the summaries table.
my $count = 0;
my $perquery = 1000;

my @outCases;
my @needLookup;

my $activeClause;
if ($active) {
	$activeClause = " AND casestatus NOT IN ('Closed', 'Disposed') ";
}
else{
	$activeClause = "";
}

while ($count < scalar(@cases)) {
    my @temp;
    getArrayPieces(\@justcases, $count, $perquery, \@temp, 1);
    my $inString = join(",", @temp);
    
    $query = qq {
        select
            casenum as "CaseNumber",
            division as "DivisionID",
            active as "Active",
            style as "CaseStyle",
            DATE_FORMAT(filedate, '%m/%d/%Y') as "FileDate",
            caseage as "CaseAge",
            DATE_FORMAT(lastactdate,'%m/%d/%Y') as "LastActivityDate",
            CASE
                WHEN ((nextactdate is not null) and (nextactdate <> '0000-00-00')) THEN
                    DATE_FORMAT(nextactdate,'%m/%d/%Y')
                ELSE
                    '&nbsp;'
            END as "NextEventDate",
            casetype as "CaseType",
            casestatus as "CaseStatus",
            notes as "Notes"
        from
            summaries
        where
            casenum in ($inString)
            $activeClause
        order by
            casenum
    };
    
    my %caseList;
    getData(\%caseList,$query,$icmsconn,{hashkey => "CaseNumber"});
    
    my %caseFlags;
    $query = qq {
        select
            f.casenum as "CaseNumber",
            f.flagtype as "FlagType",
            ft.dscr as "FlagDescription",
            f.userid as "User",
            f.date as "FlagDate"
        from
            flags f left outer join flagtypes ft on (f.flagtype = ft.flagtype)
        where
            casenum in ($inString)
    };
    
    getData(\%caseFlags,$query,$icmsconn,{hashkey => "CaseNumber"});
    
    my %caseNotes;
    $query = qq {
        select
            casenum as "CaseNumber",
            note as "CaseNote",
            userid as "User",
            date as "NoteDate"
        from
            casenotes
        where
            casenum in ($inString)
        order by
            date desc
    };
    getData(\%caseNotes, $query, $icmsconn, {hashkey => "CaseNumber"});
   
    # Now go through these cases and see if we have summaries for all of them that were listed.  Keep track of those that were not, so we can
    # look up the information later.
    foreach my $case (@temp) {
        $case =~ s/\'//g;
        if (defined($caseList{$case})) {
            my $thisCase = $caseList{$case}[0];
            # Also, while we're here, sanitize the case style a little bit.
            $thisCase->{'CaseStyle'} = prettifyString($thisCase->{'CaseStyle'});
            
            # Now add the matched flags.  We want to put the SEARCHED FOR flag first, and then put the
            # others alphabetically.
            $thisCase->{'Flags'} = [];
            my @otherFlags;
            
            # Search and find the matched flag and put it first
            for (my $index = 0; $index < scalar(@{$caseFlags{$case}}); $index++) {
                if (inArray(\@flagTypeArr, $caseFlags{$case}[$index]->{'FlagType'})) {
                    push(@{$thisCase->{'Flags'}}, $caseFlags{$case}[$index]);
                } else {
                    push(@otherFlags, $caseFlags{$case}[$index]);
                }
                # Now sort the other flags alphabetically, and push them onto the end of the Flags array
                
            }
            my @sorted = sort {$a->{'FlagDescription'} cmp $b->{'FlagDescription'}} @otherFlags;
            push(@{$thisCase->{'Flags'}}, @sorted);
            
            if (defined($caseNotes{$case})) {
                $thisCase->{'CaseNotes'} = $caseNotes{$case};
            } else {
                $thisCase->{'CaseNotes'} = [];
            }
            
            
            push(@outCases, $thisCase);
        } else {
            push (@needLookup, $case);
        }
    }
    
    $count += $perquery;
}


my %data;
if (scalar(@outCases)) {
	$data{'outCases'} = \@outCases;
}
$data{'casecount'} = scalar(@outCases);
$division =~ s/'//g;
$data{'division'} = $division;
$data{'active'} = $active;
if ($startDate eq "1970-01-01") {
	$data{'dates'} = "All"
} else {
	my @temp = split("-", $startDate);
	$startDate = sprintf("%04d-%02d-%02d", @temp);
	@temp = split("-", $endDate);
	$endDate = sprintf("%04d-%02d-%02d", @temp);
	$data{'dates'} = "$startDate - $endDate";
}

if ($flagTypes =~ /,/) {
	$data{'flag'} = "multiple selected";
} elsif ($flagTypes ne 'all') {
	$query = qq {
		select
			dscr
		from
			flagtypes
		where
			flagtype = ?
	};
	my $flagdesc = getDataOne($query,$icmsconn,[$flagTypes]);
	$data{'flag'} = $flagdesc->{'dscr'};
}

if (defined($params{'toexcel'})) {
	my @columns = (
		{
			'FieldName' => 'CaseNumber',
			'Type' => 'CL',
			'Header' => 'Case #'
		},
		{
			'FieldName' => 'DivisionID',
			'Type' => 'C',
			'Header' => 'Div'
		},
		{
			'FieldName' => 'CaseStyle',
			'Type' => 'T',
			'Header' => 'Name'
		},
		{
			'FieldName' => 'FileDate',
			'Type' => 'C',
			'Header' => 'Initial File'
		},
		{
			'FieldName' => 'CaseAge',
			'Type' => 'I',
			'Header' => 'Age'
		},
		{
			'FieldName' => 'LastActivityDate',
			'Type' => 'C',
			'Header' => 'Last Activity'
		},
		{
			'FieldName' => 'NextEventDate',
			'Type' => 'C',
			'Header' => 'Next Event'
		},
		{
			'FieldName' => 'CaseType',
			'Type' => 'C',
			'Header' => 'Type'
		},
		{
			'FieldName' => 'CaseStatus',
			'Type' => 'C',
			'Header' => 'Status'
		},
		{
			'FieldName' => 'ExportFlags',
			'Type' => 'T',
			'Header' => 'Flags'
		},
		{
			'FieldName' => 'Notes',
			'Type' => 'T',
			'Header' => 'Notes'
		}
	);
    
    # We need format the ExportFlags column from the Flags
    foreach my $case (@outCases) {
        $case->{'ExportFlags'} = $case->{'Flags'}[0]->{'FlagDescription'};
        
        my @addlFlags;
        for (my $index = 1; $index < scalar(@{$case->{'Flags'}}); $index++) {
            push(@addlFlags, $case->{'Flags'}[$index]->{'FlagDescription'});
        }
        if (scalar(@addlFlags)) {
            $case->{'ExportFlags'} .= ": " . join("; ", @addlFlags);
        }
    }

	my $title = "Flagged Case Search for Flag $data{'flag'}, Division $data{'division'}, Flagged Dates $data{'dates'} - $data{'casecount'} Rows";
	my $sheetname = makeSpreadsheet($title,"/var/www/html/tmp",\@columns,\@outCases);
	my $fname = "/tmp/" . basename($sheetname);
	print $info->redirect($fname);
} else {
#	print $info->header('application/json');
#    my $json_text = JSON->new->ascii->pretty->encode(\%data);
#    print $json_text;
    my %result;
    $result{'status'} = "Success";
    $result{'html'} = doTemplate(\%data,"$templateDir/casenotes","flagCaseList.tt",0);
    returnJson(\%result);
}
exit;
