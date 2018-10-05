#!/usr/bin/perl -w

use lib "../bin";

use strict;
use ICMS;
use CGI;
use CGI::Carp qw(
    fatalsToBrowser
    );
use Template;
use Banner qw(
    getDocketItems
    buildImageList
    );
use Data::Dumper qw(Dumper);
use File::Basename;

my $info = CGI->new;

my @processCases = (
    '2011CT028610AXX',
    '2007CF012854AXX',
    '2010-CT-009589-AXX'
);

my %data;

my $process = $info->param('process');

if (!defined $process) {
    print $info->header();
    my @cases;
    foreach my $case (@processCases) {
        my %hash;
        $hash{casenum} = $case;
        push(@cases,\%hash);
    }

    $data{'cases'} = \@cases;

    doTemplate(\%data,undef,"multiCasePdf.html.tmpl",1);
    exit;
}

my $pdf = processCases ($info);

my $location = "http://$ENV{'HTTP_HOST'}/$pdf";
print $info->redirect($location);
exit;


sub processCases {
    my $info = shift;

    if (!defined ($info->param('cases'))) {
        print $info->header();
        print "No cases specified.  Exiting.\n\n";
        exit;
    }

    my @cases = $info->param('cases');

    # A hash, keyed on the case number, of hashes of docket items for each case
    my %dockets;
    my %fullDocs;
    # A list of the files returned by buildImageList, which will then be used
    # to create the master PDF and ensure they're in order.
    my %listfiles;

    # We have a list of cases to process.
    foreach my $case (@cases) {
        # Clean up the case number a bit
        $case =~ s/-//g;
        $case =~ s/\s$//g;
        $case =~ s/^\s+//g;

        $dockets{$case} = [];

        my %requestInfo;
        $requestInfo{casenum} = $case;
        $requestInfo{showmulti} = "All-in-One";
        getDocketItems(\%requestInfo, $dockets{$case});

        # Move along if no docket items found.
        next if (!scalar(@{$dockets{$case}}));

        my @documents;

        # Get the desired list of files and build a PDF for this particular case
        my $pdfListFile = buildImageList($dockets{$case}, \@documents);

        $listfiles{$case} = $pdfListFile;

        # Push the array
        $fullDocs{$case} = \@documents;

        # And make a note of the PDF.
    }

    # The page number of the last page of the previous case.  Trust me on this.
    my $listfh = new File::Temp (
	UNLINK => 0,
	DIR => "/tmp"
	);

    my $listfn = $listfh->filename;
    my @images;

    my $prevLast = 0;
    foreach my $key (sort keys %fullDocs) {
        my $itemCount = scalar(@{$fullDocs{$key}});
        my $lastPage = $fullDocs{$key}[$itemCount - 1]->{'lastPage'};
        foreach my $item (@{$fullDocs{$key}}) {
            $item->{page} += $prevLast;
            $item->{lastPage} += $prevLast;
        }
        $prevLast += $lastPage;

        # Copy the PDF list file into the master file
        open (INFILE, $listfiles{$key});
        while (my $line = <INFILE>) {
            print $listfh $line;
            chomp $line;
            push(@images, $line);
        }
        close INFILE;
    }

    close $listfh;

    # And make the single image file for this image.
    my $pdf = buildImageFile($listfn, \@images, \%fullDocs, undef,
                                  "pdfmarks.multicase.tt");

    return $pdf;
}


#sub buildMultiImageFile {
#    my $pdfListFile = shift;
#    my $imageref = shift;
#    my $docref = shift;
#    my $case = shift;
#    my $templateFile = shift;
#    my $tmpFileDir = shift;
#
#    if (!defined($templateFile)) {
#        $templateFile = "pdfmarks.singlecase.tt";
#        }
#
#    if (!defined($tmpFileDir)) {
#        $tmpFileDir = $htmlTemp;
#        }
#
#    # Generate the configfile with a temp name
#    my $cfgfh = File::Temp->new(
#        DIR => "/tmp",
#        UNLINK => 1
#        );
#
#    my $cfgfile = $cfgfh->filename;
#
#    # We don't actually need the filehandle here, just a unique filename
#    close $cfgfh;
#
#    my $rdfile = basename($cfgfile) . ".pdf";
#
#    my $command;
#
#    if (scalar(@{$imageref}) > 1) {
#        # Only use bookmarks if there is more than 1 image.
#        my $tt = Template->new( {
#            INCLUDE_PATH => "/usr/local/icms/templates",
#            ABSOLUTE => 1
#            }
#                               );
#
#        $tt->process($templateFile, {
#            documents => $docref,
#            case => $case
#            },
#                     $cfgfile
#                     ) ||
#        die $tt->error;
#
#        $command = "gs -q -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOUTPUTFILE=".
#        "$tmpFileDir/$rdfile -f $cfgfile \@$pdfListFile > /dev/null 2>&1";
#        system ("cp $cfgfile /tmp/rich");
#
#        } else {
#        $command = "gs -q -dBATCH -dNOPAUSE -sDEVICE=pdfwrite -sOUTPUTFILE=".
#        "$tmpFileDir/$rdfile \@$pdfListFile > /dev/null 2>&1";
#        }
#
#    # Remove old copies if they exist.
#    if (-e "$tmpFileDir/$rdfile") {
#        unlink ("$tmpFileDir/$rdfile");
#        }
#
#    my $res = system($command);
#
#    if (!$res) {
#        # Clean up the "temporary" PDFs before redirecting
#        open (INFILE, $pdfListFile);
#        while (my $pdfFile = <INFILE>) {
#            chomp $pdfFile;
#            if (-f $pdfFile) {
#                unlink($pdfFile);
#                }
#            }
#        return "tmp/$rdfile";
#    } else {
#        # Clean up the "temporary" PDFs before whining
#        open (INFILE, $pdfListFile);
#        while (my $pdfFile = <INFILE>) {
#            chomp $pdfFile;
#            if (-f $pdfFile) {
#                unlink($pdfFile);
#                }
#            }
#        return undef;
#        }
#    }



sub doTemplate {
    my $dataref = shift;
    my $singleref = shift;
    my $templateFile = shift;
    my $printOutput = shift;

    my $tt = Template->new (
                            {
                                INCLUDE_PATH => "/usr/local/icms/templates"
                            }
                           );

    my $output;
    $tt->process(
                $templateFile, { data => $dataref }, \$output
                );

    if ($printOutput) {
        print $output;
        return undef;
    } else {
        return $output;
    }
}
