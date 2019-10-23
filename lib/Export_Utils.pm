package Export_Utils;

BEGIN {
    use lib "$ENV{'JVS_PERL5LIB'}";
}

use strict;
use warnings;

require Exporter;
our @ISA = qw(Exporter);
our @EXPORT_OK = qw(
    makeSpreadsheet
);

use Spreadsheet::WriteExcel;
use File::Temp qw (
    tempfile
);
use Common qw(dumpVar);
use HTML::Strip;
use Switch;


sub makeSpreadsheet {
    my $title = shift;
    my $outputDir = shift;
    # A reference to an array of hashes.  Each hash will contain 3 fields: 1) The header to be
    # shown; 2) the type of data; 3) The name of the corresponding field in the data indices.
    # THE ORDER DOES MATTER!!!
    my $columns = shift;
    # A reference to an array of hashes; elements should correspond to elements in the $columns
    # ref
    my $data = shift;
    my $formatHash = shift;
    
    my $protocol = "http";
    if (defined $ENV{'HTTPS'}) {
        $protocol = "https"
    }
    my $url = sprintf("%s://%s/cgi-bin/", $protocol, $ENV{'HTTP_HOST'});
    
    if (!defined($formatHash)) {
        $formatHash = {};
        $formatHash->{'titleSize'} = 14;
        $formatHash->{'titleRowHeight'} = 18;
        $formatHash->{'textSize'} = 12;
    }

    my %fields;
    foreach my $column (@{$columns}) {
        # Build an array of the types, keyed on the data field.  Trust me - it'll be handy
        # when we're building the sheet
        $fields{$column->{'FieldName'}} = $column->{'Type'};
    }
    
    my ($fh, $filename) = tempfile (
        DIR => $outputDir,
        SUFFIX => ".xls"
    );
    # We only wanted a unique filename.
    close($fh);
    
    # Set up some formatting
    my $workbook = Spreadsheet::WriteExcel->new($filename);
    my $worksheet = $workbook->add_worksheet();
    
    my $titleFmt = $workbook->add_format();
    $titleFmt->set_bold();
    $titleFmt->set_size($formatHash->{'titleSize'});
    
    my $headerFmt =$workbook->add_format();
    $headerFmt->set_bold();
    $headerFmt->set_underline();
    $headerFmt->set_align('center');
    
    my $centerFmt = $workbook->add_format();
    $centerFmt->set_align('center');
    
    my $leftFmt = $workbook->add_format();
    $leftFmt->set_align('left');
    
    # Now write the title.
    $worksheet->set_row(0,$formatHash->{'titleRowHeight'});
    $worksheet->write(0,0,$title,$titleFmt);
    
    my @maxwidths;
    
    # Now the column headers
    my $col = 0;
    foreach my $field (@{$columns}) {
        $worksheet->write(2,$col,$field->{'Header'},$headerFmt);
        $maxwidths[$col] = ((length($field->{'Header'}) * $formatHash->{'textSize'} / 10) * 1.5);
        $col++;
    }
    
    my $row = 3;
    foreach my $record (@{$data}) {
        my $col = 0;
        foreach my $field (@{$columns}) {
            my $hs = HTML::Strip->new();
            my $text = $hs->parse($record->{$field->{'FieldName'}});
            my $format;
            my $link = "";
            switch ($field->{'Type'}) {
                case 'C' {
                    $format = $centerFmt;
                }
                case 'CL' {
                    $link = qq{$url/search.cgi?name=$text};
                }
                else {
                    $format = $leftFmt;
                }
            }
            if ($link eq "") {
                $worksheet->write($row,$col,$text,$format);
            } else {
                $worksheet->write_url($row,$col,$link,$text);
            }
            my $thisWidth = (length($text) * $formatHash->{'textSize'} / 10);
            if ($thisWidth > $maxwidths[$col]) {
                $maxwidths[$col] = $thisWidth;
            }
            $col++;
        }
        $row++;
    }
    
    # Now go throught the columns and set the widths according to the computed maxima.
    for (my $count = 0; $count < scalar(@maxwidths); $count++) {
        $worksheet->set_column($count, $count, $maxwidths[$count]);
    }
    
    $workbook->close();
    return $filename;
}

1;
