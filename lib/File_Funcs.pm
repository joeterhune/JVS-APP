package File_Funcs;
use strict;
use warnings;

use Fcntl qw(:DEFAULT :flock);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
	getLock
);


sub getLock {
	# Gets an exclusive lock on the specified file; useful for ensuring that only 1 instance of a program is running.
	my $lockfile = shift;
	my $timeout = shift;  # Timeout in seconds
	
	if (!defined($timeout)) {
		$timeout = 10;
	}
	
	eval {
		local $SIG{ALRM} = sub { die "timeout\n" };
		alarm $timeout;
		open (LOCK, ">$lockfile") ||
			die "Unable to open lock file '$lockfile': $!\n\n";
		flock (LOCK, LOCK_EX);
		alarm 0;
	};
	if ($@) {
		warn "Unable to obtain exclusive lock on '$lockfile'";
		return 0;
	}
	return 1;
}


1;
