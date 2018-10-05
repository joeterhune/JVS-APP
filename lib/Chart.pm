package Chart;
use strict;
use warnings;
use File::Temp;
use File::Basename;
use XML::Simple;
use ICMS;
use DBI qw(:sql_types);

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    createChart
    readConfXml
    $chartConfDir
    pendingChart
    insertChartData
    );

our $chartConfDir = "/usr/local/icms/etc/reportconfigs";

sub createChart{
    my $config = shift;
    my $chartData = shift;
    # Assumes that the user DOES want a file created; if so, the name of the
    # created file will be returned.  If not, the full XML string for
    # FusionCharts will be returned.
    my $noFile = shift;

    my @requiredElements = (
      "swfDir",
      "reportDir",
      "chartType"
    );

    if (!defined($config->{'chartTmpDir'})) {
        $config->{'chartTmpDir'} = "/var/www/html/tmp";
    }

    # Strip the HTTP DocumentRoot from chartTmpDir
    my $docTmpDir = $config->{'chartTmpDir'};
    $docTmpDir =~ s/^$ENV{'DOCUMENT_ROOT'}//g;

    if (!checkRequired($config, \@requiredElements)) {
        return undef;
    }

    # Build the XML string for the chart
    my $string = "<chart ";
    foreach my $key (keys %{$config->{'chartStyleElements'}}) {
        # Add all of the style elements
        $string .= "$key=\"$config->{'chartStyleElements'}->{$key}\" ";
    }
    $string .= ">\n";

    # And now the data
    foreach my $element (@{$chartData}) {
        $string .= "\t<set label=\"$element->{'label'}\" ".
            "value=\"$element->{'value'}\"/>\n";
    }
    # And close the string
    $string .= "</chart>\n";

    if ($noFile) {
        return $string;
    } else {
        # Ok, we should have everything we need. Build the file.
        my $fh = new File::Temp (
            DIR => $config->{'chartTmpDir'},
            UNLINK => 0
            );
        my $chartFile = $fh->filename;
        print $fh $string;
        close $fh;
        return $docTmpDir . "/" . basename($chartFile);
    }
}


sub checkRequired {
    # Checks a hash reference to be sure that every required element (the list
    # is defined in @{$arrayref}) is defined.  For each that doesn't exist, a
    # message is logged to STDERR, and if any are not found, the function
    # returns 0.
    my $hashref = shift;
    my $arrayref = shift;

    my $listComplete = 1;

    foreach my $item (@{$arrayref}) {
        if (!defined ($hashref->{$item})) {
            print STDERR "No hash key '$item' found.\n";
            $listComplete = 0;
        }
    }
    return $listComplete;
}


sub readConfXml {
    # Reads an XML config file and pushes the information onto a hash reference
    my $config = shift;
    my $xmlfile = shift;

    my $xml = XML::Simple->new();
    my $conf = $xml->XMLin($xmlfile);

    foreach my $key (sort keys %{$conf}) {
        $config->{$key} = $conf->{$key};
    }
}


sub pendingChart {
    my $config = shift;
    my $string = shift;
    my $age = shift;

    foreach my $range (@{$config->{'pendingWithEvents'}->{'dayRange'}}) {
        if (defined($range->{'upper'})) {
            if (($range->{'lower'} <= $age) && ($age <= $range->{'upper'})) {
                $range->{'value'}++;
                # Push a reference to the case onto the list
                push(@{$range->{'caseList'}}, \$string);
                last;
            }
        } elsif ($range->{'lower'} <= $age){
            # No upper limit defined for this range
            $range->{'value'}++;
            # Push a reference to the case onto the list
            push(@{$range->{'caseList'}}, \$string);
            last;
        }
    }
}


sub insertChartData {
    my $chartData = shift;
    my $dbh = shift;

    if (!$dbh) {
        $dbh = dbconnect("metrics");
    }

    # First drop the records - we only keep 1 per month (for archival charts)
    my $query = qq {
        delete from
            graphdata
        where
            division='$chartData->{division}' and
            crit='$chartData->{crit}' and
            title='$chartData->{title}' and
            month='$chartData->{month}' and
            year='$chartData->{year}'
    };

    $dbh->do($query);

    # And now do the insert.

    $query = qq {
	insert into
	    graphdata
		(
		    division,
		    crit,
		    title,
		    count,
		    month,
                    year
		)
	    values
		(?,?,?,?,?,?)
      };

      my $sth = $dbh->prepare($query);
      $sth->bind_param(1,$chartData->{'division'},SQL_VARCHAR);
      $sth->bind_param(2,$chartData->{'crit'},SQL_VARCHAR);
      $sth->bind_param(3,$chartData->{'title'}, SQL_VARCHAR);
      $sth->bind_param(4,$chartData->{'count'}, SQL_INTEGER);
      $sth->bind_param(5,$chartData->{'month'},SQL_INTEGER);
      $sth->bind_param(6,$chartData->{'year'},SQL_INTEGER);
      $sth->execute();
}


1;
