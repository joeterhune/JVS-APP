#!/usr/bin/perl -w

BEGIN {
    use lib $ENV{'PERL5LIB'};
}

use strict;

use Common qw (
    dumpVar
    getArrayPieces
    today
    ISO_date
    getUser
    uploadFile
    encodeFile
);
use XML::Simple;
use DB_Functions qw (
    dbConnect
    doQuery
    inGroup
    lastInsert
);
use Casenotes qw (
    calcExpire  
);
use JSON;
use CGI;
use File::Basename;

my $info = new CGI;
my $conf = XMLin("$ENV{'APP_ROOT'}/conf/ICMS.xml");
my $notesGroup = $conf->{'ldapConfig'}->{'notesgroup'};
my $user = getUser();
if (!inGroup($user, $notesGroup)) {
    print $info->header;
    print "You do not have rights to use this function.\n";
    exit;
}

print $info->header('application/json');

my %params = $info->Vars;

my @cases = split(",", $params{'cases'});
my $note = $params{'note'};
my $private = $params{'private'};
my $attachment = $params{'attachment'};

if ($params{'attachment'} ne "") {
    # There is a file annotation to add.
    $attachment = uploadFile($info, "attachment");
}

my $today = ISO_date(today());

my $dbh = dbConnect("icms");

# Make it a transaction!
$dbh->begin_work;

my %result;
$result{'UpdateCount'} = 0;
$result{'Completed'} = [];

foreach my $rec (@cases) {
    my ($case, $div) = split(/\|/, $rec);
    my $query = qq {
        insert into
            casenotes (
                casenum, userid, date, private, note, division, active
            ) values (
                ?, ?, ?, ?, ?, ?, ?
            )
    };
    doQuery($query, $dbh, [$case, $user, $today, $private, $note, $div, 1]);
    push(@{$result{'Completed'}}, $case);
    $result{'UpdateCount'}++;
    
    if (defined($attachment)) {
	    # We have a file annotation to attach.  First, we need the ID of the newly-inserted note.
	    my $noteID = lastInsert($dbh);
	    
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
	    my $encodedFile = encodeFile($attachment);
	    doQuery($query, $dbh, [$noteID, basename($attachment), $encodedFile]);
	}
}

$dbh->commit;

my $json_text = JSON->new->ascii->pretty->encode(\%result);
print $json_text;