#!/usr/bin/perl

BEGIN {
	use lib "/usr/local/icms/bin";
}

use strict;
use Common qw (
	dumpVar
	getArrayPieces
);
use DB_Functions qw (
	dbConnect
	getData
	getDataOne
);

my $cndbh = dbConnect("icms");

$SIG{'INT'} = 'cleanup';

my @casenums;

# Get all of the casenums from the flags and casenotes tables.
my $query = qq {
	select
		distinct(casenum)
	from
		flags
	UNION
	select
		distinct(casenum)
	from
		casenotes
	order by
		casenum
};

getData(\@casenums,$query,$cndbh);

my @banncases;
my @sccases;

foreach my $casenum(@casenums) {
	if ($casenum->{'casenum'} =~ /^50-/) {
		push(@sccases,$casenum->{'casenum'});
	} else {
		push(@banncases,$casenum->{'casenum'});
	}
}

# Don't autocommit, for speed

$cndbh->begin_work;

my $scdbh = dbConnect("showcase-prod");

my $counter = 0;
my $perquery = 100;

print "There are " . scalar(@sccases) . " Showcase cases.\n";

while ($counter <= scalar(@sccases)) {
	my @temp;
	getArrayPieces(\@sccases,$counter,$perquery,\@temp);
	my $inString;
	
	if(!scalar(@temp)) {
		last;
	}
	
	if (scalar(@temp)) {
		$inString = join(",", @temp);
		$query = qq {
			select
				DivisionID,
				CaseNumber
			from
				vCase
			where
				CaseNumber in ($inString)
		};

		my %divs;
		getData(\%divs,$query,$scdbh,"CaseNumber");
	
		foreach my $key (keys (%divs)) {
			next if (!defined($divs{$key}[0]->{'DivisionID'}));
			my $div = $divs{$key}[0]->{'DivisionID'};
			$query = qq {
				update
					flags
				set
					division='$div'
				where
					casenum='$key'
			};
			$cndbh->do($query);

			$query = qq {
				update
					casenotes
				set
					division='$div'
				where
					casenum='$key'
			};
			$cndbh->do($query);
		}
		$counter += $perquery;
		print "Updated $counter criminal cases so far...\n";
	}
}

$scdbh->disconnect;

my $bdbh = dbConnect("wpb-banner-prod");
$counter = 0;

print "There are " . scalar(@banncases) . " Showcase cases.\n";

while ($counter <= scalar(@banncases)) {
	my @temp;
	getArrayPieces(\@banncases,$counter,$perquery,\@temp);
	my $inString;
	
	if(!scalar(@temp)) {
		last;
	}
	
	if (scalar(@temp)) {
		# Strip dashes - for some reason, they have dashes in casenotes but not in Banner
		foreach my $var(@temp) {
			$var =~ s/-//g;
		}
		$inString = join(",", @temp);
		$query = qq {
			select
				cdbcase_division_id as "DivisionID",
				cdbcase_id as "CaseNumber"
			from
				cdbcase
			where
				cdbcase_id in ($inString)
		};

		my %divs;
		getData(\%divs,$query,$bdbh,"CaseNumber");
	
		foreach my $key (keys (%divs)) {
			next if (!defined($divs{$key}[0]->{'DivisionID'}));
			my $div = $divs{$key}[0]->{'DivisionID'};
			if ($key =~ /(\d\d\d\d)(\D\D)(\d\d\d\d\d\d)/) {
				my $casenum = sprintf("%04d-%s-%06d", $1, $2, $3);

				$query = qq {
					update
						flags
					set
						division='$div'
					where
						casenum='$casenum'
				};
				$cndbh->do($query);

				$query = qq {
					update
						casenotes
					set
						division='$div'
					where
						casenum='$casenum'
				};
				$cndbh->do($query);
			}
		}
		$counter += $perquery;
		print "Updated $counter civil cases so far...\n";
	}
}

cleanup();

sub cleanup {
	# Commit Casenotes transactions
	print "Cleaning up, committing and stuff...\n";
	$cndbh->commit();
	print "Done!!\n\n";
    exit(0);
}

