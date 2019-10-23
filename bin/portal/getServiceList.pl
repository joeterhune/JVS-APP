#!/usr/bin/perl -w

use strict;
use SOAP::WSDL;
use Data::Dumper qw(Dumper);

my $wsdl = "https://test.myflcourtaccess.com/wsdl/ElectronicServiceListService.wsdl";

my $soap = SOAP::WSDL->new (
    wsdl => $wsdl
);

my %data;
$data{'request'}{'LogonName'} = 'rhaney';
$data{'request'}{'PassWord'} = 'Kbrh0120';
$data{'request'}{'CaseId'} = 1029;

#print Dumper \%data;
#exit;

my $result = $soap->call('GetElectronicServiceListCase', %data);

print Dumper $result;