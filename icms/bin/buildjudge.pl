#!/usr/bin/perl

BEGIN {
	use lib "$ENV{'PERL5LIB'}";	
};

use strict;
use ICMS;
use Common qw(dumpVar);
use DB_Functions qw (
	dbConnect
	getData
	getDivJudges
	getDbSchema
);

my %divJudges;
getDivJudges(\%divJudges);
my %divassign;

my $scdbh = dbConnect("showcase-prod");
my $schema = getDbSchema("showcase-prod");

# And add the Showcase divs onto the same array
my $query = qq {
	select
		Judge_LN as LastName,
		Judge_FN as FirstName,
		Judge_MN as MiddleName,
		DivisionID
	from
		vDivision_Judge
	where
		Division_Active = 'Yes'
		and EffectiveFrom <= GETDATE()
		and (EffectiveTo is null or EffectiveTo >= GETDATE())
};

getData(\%divassign,$query,$scdbh, {hashkey => 'DivisionID', flatten => 1});

$scdbh->disconnect;

my %judgelist;
foreach my $div (keys %divassign) {
	my $last = $divassign{$div}->{'LastName'};
	my $middle = $divassign{$div}->{'MiddleName'};
	my $first = $divassign{$div}->{'FirstName'};
	
	# Strip the "JUDGE" part (which may or may not have a space)
	$first =~ s/JUDGE\s?//g;
	
	if($last eq 'BRUSTARES KEYSER') {
		$last='KEYSER'; $middle='BRUSTARES'
	};
	
	my $judgename;
	
	if ((defined($middle)) && (length($middle) >= 1)) {
		if (length($middle) == 1) {
			$middle .= ".";
		}
		$judgename = sprintf("%s, %s %s", $last, $first, $middle)
	} else {
		$judgename = sprintf("%s, %s", $last, $first)
	}
	
	
	$judgelist{$div} = $judgename;
}

my @judgeconf;
foreach my $div (sort keys %judgelist) {
    my($name,$casetype)=split '~',$judgelist{$div};
    push @judgeconf,"$name~$div\n";
}

#force the new mental health division CFMH into file
push @judgeconf,"MARX, JUDGE KRISTA ~CFMH\n";

#force the unified family court divisions UFCL, UFCT, UFJM
push @judgeconf,"Unified Family Court ~UFCL\n";
push @judgeconf,"Unified Family Court ~UFCT\n";
push @judgeconf,"Unified Family Court ~UFJM\n";

@judgeconf=sort(@judgeconf);
open OUTFILE,">/usr/local/icms/etc/judgepage.conf";
print OUTFILE @judgeconf;
close OUTFILE;
