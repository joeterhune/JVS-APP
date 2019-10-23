#!/usr/bin/perl -w

BEGIN {
	$ENV{ORACLE_HOME}="/usr/lib/oracle/11.2/client";
	$ENV{LD_LIBRARY_PATH}="/usr/lib/oracle/11.2/client/lib";
	$ENV{TNS_ADMIN}="/var/www/";
	use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;
use CGI;
use CGI::Carp qw(fatalsToBrowser);

use DB_Functions qw (
	dbConnect
	getData
);

use XML::Simple;

my $info = new CGI;

print $info->header('text/xml');

my $casenum = $info->param('id');
my $div = $info->param('division');

# We want to get the case number into something we can easily work with using regex backreferences
# to make the case number the format we want

my $dbh = dbConnect("wpb-banner-prod");

# First, look to see if this case is even in this division
my @caseref;
my $query = qq {
	select
		cdbcase_id as "CaseNumber"
	from
		cdbcase
	where
		cdbcase_id='$casenum'
		and cdbcase_division_id='$div'
};
getData(\@caseref,$query,$dbh);

my %result;

if (!scalar(@caseref)) {
	$result{'status'} = "Not Found";
	$result{'response'} = "Found no match for case '$casenum' in division $div";
} else {
	my %parties;
	getParties(\%parties,$casenum,$dbh);
	my $style = makeCaseStyle(\%parties,$casenum);
	$style =~ s/^\s+//g;
	$style =~ s/\s+$//g;
	$result{'status'} = "Found";
	$result{'response'} = $style;
}

my $xs = XML::Simple->new(NoAttr => 1,XMLDecl => 1, RootName => "Result");
my $xml = $xs->XMLout(\%result);
print $xml;

#print qq {<span>$style</span><input type="hidden" name="casestyle" id="casestyle" value="$style">\n};

exit;


sub getParties {
	my $partyRef = shift;
	my $case = shift;
	my $dbh = shift;
	
	my $query = qq {
		select
			cdrcpty_case_id as "CaseNumber",
			cdrcpty_seq_no as "SequenceNumber",
			cdrcpty_ptyp_code as "PartyType",
			spriden_last_name as "LastName",
			spriden_first_name as "FirstName",
			spriden_mi as "MiddleName"
		from
			cdrcpty,
			spriden,
			cdbcase
		where
			cdbcase_id='$case'
			and cdrcpty_case_id=cdbcase_id
			and cdrcpty_pidm=spriden_pidm
			and cdrcpty_ptyp_code not in ('ATTY', 'JUDG')
	};
	
	my @parties;
	getData(\@parties,$query,$dbh);
	
	foreach my $party (@parties) {
		my $hashKey = $party->{'CaseNumber'} . ";" . $party->{'SequenceNumber'};
		$partyRef->{$hashKey} = $party;
	}
}


sub makeCaseStyle {
	my $partyRef = shift;
	if (scalar keys %{$partyRef} ==0 ) {
		die "makeCaseStyle: partylist is empty."; }
	my $case_id = shift;
	my %ptype=();
	my $fullname;
	for (my $i = 1; $i <= 30; $i++) {  # 30 parties max
		my $key="$case_id;$i";
		if (!defined $partyRef->{$key}) {
			next;
		}
		my $party = $partyRef->{$key};
		
		my $firstname;
		my $middlename;
		my $lastname;
		if (!defined ($party->{'FirstName'})) {
			$firstname="";
		} else {
			$firstname = trim($party->{'FirstName'});
		}

		if (!defined ($party->{'MiddleName'})) {
			$middlename="";
		} else {
			$middlename = trim($party->{'MiddleName'});
		}
		
		if (!defined ($party->{'LastName'})) {
			$lastname="";
		} else {
			$lastname = trim($party->{'LastName'});
		}
		
		my $name="$lastname";
		$fullname="$lastname";
		
		if(length($firstname) > 0) {
			$fullname="$lastname, $firstname $middlename";
		}
		
		if ($party->{'PartyType'} =~ /DECD/) {
	  		return "Estate of $lastname, $firstname $middlename";
		} elsif ($party->{'PartyType'} =~ /WARD/) {
			return "Guardianship of $lastname, $firstname $middlename";
		} elsif ($party->{'PartyType'} =~ /^AI/) {
	  		return "Incapacity of $lastname, $firstname $middlename";
		} elsif (!defined $ptype{$party->{'PartyType'}}) {
			$ptype{$party->{'PartyType'}}=$fullname;
		} else {
			if ($ptype{$party->{'PartyType'}} !~ /, et al./) {
				$ptype{$party->{'PartyType'}}.=", et al.";
			}
		}
	}
	
	if (defined $ptype{'PLT'} and defined $ptype{'DFT'}) {
		return "$ptype{'PLT'} v. $ptype{'DFT'}";
	} elsif (defined $ptype{'CPLT'} and defined $ptype{'DFT'}) {
		return "$fullname"; # traffic cases
	} elsif (defined $ptype{'PET'} and defined $ptype{'RESP'}) {
		return "$ptype{'PET'} v. $ptype{'RESP'}";
	} else { return join " ",sort values %ptype; }
}


sub trim {
	my $string = shift;
	
	$string =~ s/^\s+//g;
	$string =~ s/\s$//g;
	return $string;
}