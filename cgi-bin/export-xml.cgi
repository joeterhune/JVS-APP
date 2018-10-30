#!/usr/bin/perl -w

BEGIN {
    use lib "$ENV{'PERL5LIB'}";
}

use strict;
use XML::Simple;
use Common qw (
    dumpVar
    getConfig
    US_date
);

use CGI;
use Spreadsheet::WriteExcel;
use Excel::Writer::XLSX;
use File::Temp;
use File::Basename;
use HTML::Strip;

my $info = new CGI;

my %params = $info->Vars;

if (!defined($params{'xmlfile'})) {
    die "No input XML file specified.";
}

# Are we building a sheet for each day, or a single sheet for all days?
my $multi = $params{'multiSheets'};

my $xs = XML::Simple->new();
# Force cases to an array, in case there's only one.
my $ref = $xs->XMLin($params{'xmlfile'}, ForceArray => ['cases'], SuppressEmpty => '' );

my $redirect = '';

if (defined($ref->{'otherInfo'}->{'exportXMLdef'})) {
    #print "Need to do it the fancy way.";
    $redirect = buildXLSX($ref, $multi);
    $redirect =~ s/\/var\/www\/html//g;
    print $info->redirect($redirect);
    exit;
}

my $exportHeaders = $ref->{'exportHeaders'};

if (!defined($exportHeaders)) {
    die "Invalid XML file: No headers specified.";
}
my $cases = $ref->{'cases'};
my $otherInfo = $ref->{'otherInfo'};

my $fh = File::Temp->new (
                          UNLINK => 0,
                          DIR => "/var/www/html/tmp",
                          SUFFIX => '.xls'
);
my $filename = $fh->filename;
# We only needed a unique name, so close the file.
close ($fh);

my $workbook=Spreadsheet::WriteExcel->new($filename);

my $worksheet=$workbook->addworksheet();

my $format0=$workbook->addformat(num_format =>'@');
#$format0->set_num_format('@');

my $format1=$workbook->addformat();
$format1->set_num_format('mm/dd/yy');
$format1->set_text_wrap;

my $format2=$workbook->addformat();
$format2->set_bold();
$format2->set_text_wrap;
$format2->set_align('center');

my $formath1=$workbook->addformat();
$formath1->set_bold();
$formath1->set_size(14);

my $formath2=$workbook->addformat();
$formath2->set_bold();
$formath2->set_size(12);

my $formath3=$workbook->addformat();
$formath3->set_bold();
$formath3->set_size(11);

my $row = 2;
my $col = 0;

my $width = scalar(@{$exportHeaders});

my $titleStr;

my $limitStr = "";
my $dobStr = "";

if ((defined($otherInfo->{'limitdiv'})) && ($otherInfo->{'limitdiv'} ne "")) {
    $limitStr = sprintf(" (%s only)", $otherInfo->{'limitdiv'});
}

if ((defined($otherInfo->{'DOB'})) && ($otherInfo->{'DOB'} ne "")) {
    $dobStr = sprintf(" (DOB %s)", $otherInfo->{'DOB'});
}

$titleStr = $otherInfo->{'dTitle'};

$worksheet->write(0,0,$titleStr,$formath1);

# For tracking approximate column width
my %max;

# Now print the headers
foreach my $header (@{$exportHeaders}) {
    $worksheet->write($row,$col,$header->{'Column'},$format2);
    $max{$col++}=length($header->{'Column'}) + 2;
};

$row++;

my $redirName = "/tmp/" . basename($filename);

my $protocol = "http";
if (defined $ENV{'HTTPS'}) {
    $protocol = "https"
}

my $link="$protocol://$ENV{'HTTP_HOST'}/cgi-bin/search.cgi?name=";

# Now the data

foreach my $case (@{$cases}) {
    $col = 0;
    foreach my $header (@{$exportHeaders}) {
        $case->{$header->{'XMLField'}} =~ s/&nbsp;/ /g;
        $case->{$header->{'XMLField'}} =~ s/<br\/>/\n/g;
        
        if (ref($case->{$header->{'XMLField'}}) eq "HASH") {
            $worksheet->write($row,$col,"",$format1)
        } elsif ($header->{'XMLField'} eq "OpenWarrants") {
            if ($case->{$header->{'XMLField'}}) {
                $worksheet->write($row,$col,'Y');
            } else {
                $worksheet->write($row,$col,'N');
            }
        } elsif ($header->{'XMLField'} eq "CaseNumber") {
            # A case link
            my $url = sprintf("%s%s", $link, $case->{$header->{'XMLField'}});
            $worksheet->write_url($row,$col, $url, $case->{$header->{'XMLField'}});
        } elsif ($header->{'XMLField'} eq "ConfNum") {
            # Need to force this as a string.
            $worksheet->write_string($row,$col,$case->{$header->{'XMLField'}});
        } elsif($header->{'XMLField'} eq "Motion"){
            my @links = grep(/<a.*href=.*>/, $case->{$header->{'XMLField'}});

			foreach my $c (@links){
			  $c =~ /<a.*href="([\s\S]+?)".*>/;
			  my $link = $1;
			  $c =~ /<a.*href.*>([\s\S]+?)<\/a>/;
			  my $title = $1;
			  $worksheet->write_url($row, $col, $link, $title);
			}
			
			if(scalar(@links) == 0){
				my $hs = HTML::Strip->new();
        		my $clean_text = $hs->parse($case->{$header->{'XMLField'}});
  				$hs->eof;
            	$worksheet->write($row, $col, $clean_text, $format1);
			}
            
        } else {
            $worksheet->write($row,$col,$case->{$header->{'XMLField'}},$format1);
        }
        
        if (not defined $max{$col} or ($max{$col}<length($case->{$header->{'XMLField'}}))) {
            $max{$col}=length($case->{$header->{'XMLField'}});
		}
        $col++;
    };
    $row++;
}

foreach (keys %max) {
    $worksheet->set_column($_,$_,$max{$_}+1);
}  

$workbook->close();

print $info->header;
print $info->redirect($redirName);
exit;


sub buildXLSX {
    my $data  = shift;
    my $multi = shift;
    
    my $config = getConfig($data->{'otherInfo'}->{'exportXMLdef'});
    $config->{'StartDate'} = $data->{'otherInfo'}->{'start'};
    $config->{'EndDate'} = $data->{'otherInfo'}->{'end'};
    $config->{'Division'} = $data->{'otherInfo'}->{'division'};
    
    my $fh = File::Temp->new (
                              UNLINK => 0,
                              DIR => "/var/www/html/tmp",
                              SUFFIX => '.xlsx'
    );
    my $filename = $fh->filename;
    
    my $workbook = Excel::Writer::XLSX->new($filename);
    
    $config->{'sheetHeader'} = $workbook->add_format(%{$config->{'SheetHeaderFormat'}});

    # Is there header image specified?  If so, get its dimensions (do it once here,
    # instead of inside a loop)
    if (defined($config->{'HeaderImage'})) {
        my $file = $config->{'HeaderImage'}->{'ImageFile'};
        #($config->{'HeaderImage'}->{'XDim'}, $config->{'HeaderImage'}->{'YDim'}) = imgsize($file);
        $config->{'ImgFormat'} = $workbook->add_format();
        $config->{'ImgFormat'}->set_align('center');
        $config->{'ImgFormat'}->set_valign('vcenter');
    }
    
    # For each of the defined columns, take the specified format XML and create a format object, one for the
    # headers and one for the data rows
    foreach my $column (@{$config->{'Column'}}) {
        if (defined($column->{'HeaderFormat'})) {
            $column->{'ColFmt'} = $workbook->add_format(%{$column->{'HeaderFormat'}});
        } else {
            $column->{'ColFmt'} = $workbook->add_format(%{$config->{'DftHeaderFormat'}});
        }
        if (defined($column->{'RowFormat'})) {
            $column->{'RowFmt'} = $workbook->add_format(%{$column->{'RowFormat'}});
        } else {
            $column->{'RowFmt'} = $workbook->add_format(%{$config->{'DftRowFormat'}});
        }
    }
    
    # Reorganize the events by Judge (and, if applicable, by date)
    my %byJudge;
    
    foreach my $event (@{$data->{'cases'}}) {
        my $judge = $event->{'JudgeName'};
        my $eventType = $event->{'EventType'};
        if (!defined($byJudge{$judge})) {
            $byJudge{$judge} = {};
        }
        my $judgeHash = $byJudge{$judge};
        
        if ($multi) {
            # Since we're doing a different sheet for each day, we need to have another level of
            # organization for the data.
            if (!defined($judgeHash->{$eventType})) {
                $judgeHash->{$eventType} = {};
            }
            my $judgeEvent = $judgeHash->{$eventType};
            if (!defined($judgeEvent->{$event->{'ISODate'}})) {
                $judgeEvent->{$event->{'ISODate'}} = [];
            }
            push(@{$judgeEvent->{$event->{'ISODate'}}}, $event);
        } else {
            if (!defined($judgeHash->{$eventType})) {
                $judgeHash->{$eventType} = [];
            }
            push(@{$judgeHash->{$eventType}}, $event);
        }
    }
    
    print $info->header;
    
    foreach my $judge (sort keys %byJudge) {
        if ($multi) {
            foreach my $eventType (sort keys %{$byJudge{$judge}}) {
                foreach my $eventDate (sort keys %{$byJudge{$judge}->{$eventType}}) {
                    my $events = $byJudge{$judge}->{$eventType}->{$eventDate};
                    addSheet($workbook, $config, $events, $judge, $eventType, $eventDate);
                }
            }
        } else {
            foreach my $eventType (sort keys %{$byJudge{$judge}}) {
                my $events = $byJudge{$judge}->{$eventType};
                addSheet($workbook, $config, $events, $judge, $eventType);
            }
        }
    }
    
    return $filename;
}




sub addSheet {
    my $workbook = shift;
    my $config = shift;
    my $events = shift;
    my $judgeName = shift;
    my $eventType = shift;
    my $eventDate = shift;
        
    # Set up column headers
    my $headers = $config->{'Column'};
    
    my $colCount = scalar(@{$headers});

    my $headerRow = $config->{'HeaderRow'};
    my $headerCol = 0;
    if (defined($config->{'HeaderCol'})) {
        $headerCol = $config->{'HeaderCol'};
    }
    
    my $judgeLast = (split(",", $judgeName))[0];
    my $sheetName;
    if (defined($eventDate)) {
        my @datePieces = split("-", $eventDate);
        my $shortDate = sprintf("%02d-%02d", $datePieces[1], $datePieces[2]);
        $sheetName = sprintf("%s - %s - %s", $judgeLast, $shortDate, $eventType);
    } else {
        $sheetName = sprintf("%s - %s", $judgeLast, $eventType);
    }

    # Truncate to 31 characters - the max allowed by Excel for a sheet name
    $sheetName = substr($sheetName,0,31);
    
    my $sheet = $workbook->add_worksheet($sheetName);
    $sheet->set_row($headerRow,undef,$config->{'hdrFormat'});
    $sheet->set_landscape();
    $sheet->fit_to_pages(1,0);
    if (defined($config->{'TopMargin'})) {
        $sheet->set_margin_top($config->{'TopMargin'});
    }
    if (defined($config->{'BottomMargin'})) {
        $sheet->set_margin_bottom($config->{'BottomMargin'});
    }
    if (defined($config->{'SideMargins'})) {
        $sheet->set_margins_LR($config->{'SideMargins'});
    }
    $sheet->set_footer('&C&A&RPage &P of &N');
    
    # Also calculate total sheet width while we're looping
    my $sheetWidth = 0;
    foreach my $header (@{$headers}) {
        my $col = $header->{'Position'} - 1;
        $sheet->set_column($col, $col, $header->{'Width'});
        $sheet->write($headerRow, $col, $header->{'Name'}, $header->{'ColFmt'});
        $sheetWidth += $header->{'Width'}
    }
    
    # Repeating rows?
    if (defined($config->{'RepeatRows'})) {
        my $start = $config->{'RepeatRows'}->{'Start'};
        my $end;
        # If end row isn't defined, set to start row
        if (defined($config->{'RepeatRows'}->{'End'})) {
            $end = $config->{'RepeatRows'}->{'End'}
        } else {
            $end = $start;
        }
        $sheet->repeat_rows($start, $end);
    }
    
    # Image for the header?
    if (defined($config->{'HeaderImage'})) {
        my $imageFile = $config->{'HeaderImage'}->{'ImageFile'};
        my $imageRow = $config->{'HeaderImage'}->{'ImageRow'};
        # Merge the appropriate number of columns in this row to accommodate the image
        $sheet->merge_range($imageRow,0,$imageRow,($colCount - 1),'',$config->{'ImgFormat'});
        $sheet->set_row($imageRow,$config->{'HeaderImage'}->{'YHeight'});
        my $xOffset =$config->{'HeaderImage'}->{'XOffset'};
        $sheet->insert_image($imageRow, 0, $imageFile, $xOffset, 0);
    }
    
    # Rest of the header, centered across the number of columns
    my $division = $config->{'Division'};
    centerText($sheet, "Division $division - Hearing Schedule", 1, $colCount, $config->{'sheetHeader'});
    my $date;
    if (defined($eventDate)) {
        $date = US_date($eventDate);
    } else {
        if ($config->{'StartDate'} eq $config->{'EndDate'}) {
            $date = US_date($config->{'StartDate'});    
        } else {
            $date = sprintf("%s - %s", US_date($config->{'StartDate'}), US_date($config->{'EndDate'}));
        }
    }
    
    centerText($sheet, "$date - $eventType", 2, $colCount, $config->{'sheetHeader'});
    centerText($sheet, "Judge - $judgeName", 3, $colCount, $config->{'sheetHeader'});
    
    # Now the data
    my @columns = sort { $a->{'Position'} <=> $b->{'Position'} } @{$config->{'Column'}};
    my $dataRow = $headerRow + 1;
    foreach my $event (@{$events}) {
        $sheet->set_row($dataRow, $config->{'RowHeight'});
        for (my $i = 0; $i < $colCount; $i++) {
            # Find the appropriate column
            my $field = $columns[$i]->{'Field'};
            if ($field eq 'CaseNumber') {
                if ((defined($config->{'Show50'})) && (!$config->{'Show50'})) {
                    $event->{$field} =~ s/^50-{0,1}//;
                }
            }
            
            if ($field eq 'CaseNumber') {
                my $url = sprintf("http://jvs.15thcircuit.com/cgi-bin/search.cgi?name=%s", $event->{'CaseNumber'});
                $sheet->write_url($dataRow, $i, $url, $columns[$i]->{'RowFmt'}, $event->{'CaseNumber'});
            } else {
            	$event->{$field} =~ s|<.+?>| |g;
                $sheet->write($dataRow, $i, $event->{$field}, $columns[$i]->{'RowFmt'});   
            }
        }
        $dataRow++;
    }
}

sub centerText {
    my $sheet = shift;
    my $string = shift;
    my $row = shift;
    my $max = shift;
    my $format = shift;
    
    $sheet->write($row,0,$string,$format);
    for (my $i = 1; $i < $max; $i++) {
        $sheet->write_blank($row,$i,$format);
    }
}
