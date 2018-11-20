#!/usr/bin/perl

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;
use Common qw (
	doTemplate
	$templateDir
	ISO_date
    returnJson
    uploadFile
    encodeFile
    checkLoggedIn
    getUser
    getSession
    createTab
);

use DB_Functions qw (
	doQuery
	dbConnect
    lastInsert
    log_this
    getSubscribedQueues
	getSharedQueues
	getQueues
);

use Casenotes qw (
	updateSummaries
);

use File::Basename;

use CGI;

checkLoggedIn();

my $info = new CGI;

my %params = $info->Vars;

my %result;

my $annotation = undef;

if ($params{'annotation'} ne "") {
    # There is a file annotation to add.
    $annotation = uploadFile($info, "annotation");
}

# Convert the date to a MySQL-friendly format
$params{'date'} = ISO_date($params{'date'});

my $private = 0;
if (defined($params{'private'})) {
    $private = $params{'private'};
}


my $query = qq {
	insert into
		casenotes (
			casenum,
			userid,
			date,
			note,
			division,
            private,
            active
		)
		values (
			?,
			?,
			?,
			?,
			?,
            ?,
            1
		)
};

my $dbh = dbConnect("icms");
my $user = getUser();
my $session = getSession();

my @myqueues = ($user);
my @sharedqueues;

getSubscribedQueues($user, $dbh, \@myqueues);
getSharedQueues($user, $dbh, \@sharedqueues);
my @allqueues = (@myqueues, @sharedqueues);
my %queueItems;

my $wfcount = getQueues(\%queueItems, \@allqueues, $dbh);
createTab("Flags and Notes", "/casenotes/addnote.cgi?ucn=" . $params{'casenum'}, 1, 1, "cases");
my $session = getSession();

my $note = $params{'note'};

# Translate newlines to <br> tags, so it'll display nicely in ICMS.
$note =~ s/\r\n/<br\/>/g;
$note =~ s/\n/<br\/>/g;

$params{'dateval'} = ISO_date($params{'dateval'});

my $querycase = $params{'casenum'};
# modified 11/20/2018 jmt benchmark has no dashes
#if ($querycase =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
#    $querycase = sprintf("%04d-%s-%06d", $1, $2, $3);
#}

my @vals = ($querycase,getUser(),$params{'date'},$note,$params{'division'}, $private);

doQuery($query,$dbh,\@vals);

my $noteID = lastInsert($dbh);

my $logMsg = sprintf("User %s added note '%s' to case %s", getUser(), $note, $querycase);
log_this('JVS','flagsnotes',$logMsg, $ENV{'REMOTE_ADDR'}, $dbh);

if (defined($annotation)) {
    # We have a file annotation to attach.  First, we need the ID of the newly-inserted note.
    
    my $query = qq {
        insert into
            casenote_attachments (
                note_id,
                filename,
                encoded_attachment
            ) values (
                ?,?,?
            )
    };
    
    # Encode the file
    my $encodedFile = encodeFile($annotation);
    doQuery($query, $dbh, [$noteID, basename($annotation), $encodedFile]);
    $result{'annotation'} = $annotation;
}

my %data;

updateSummaries($params{'casenum'}, $dbh);

$data{'status'} = "Success";
$data{'ucn'} = $params{'casenum'}; #modified 10/20/2018 jmt data(unc) to casenum
$data{'wfCount'} = $wfcount;
$data{'active'} = "cases";
$data{'tabs'} = $session->get('tabs');


doTemplate(\%data, "$templateDir/top", "header.tt", 1);
doTemplate(\%data,"$templateDir/casenotes","addnote2.tt",1);
