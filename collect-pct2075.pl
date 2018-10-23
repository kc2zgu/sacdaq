#!/usr/bin/perl

use strict;
use warnings;

use Device::I2C;
use Fcntl;

my $i2c = Device::I2C->new("/dev/i2c-1", O_RDWR);

my %sensdata = (AGENT => "PCT2075 Agent",
		DIMENSION => "TEMP", UNIT => "Celsius",
		VALUE => 0,
		VALID => 0,
		FAULTS => "none");

if ($i2c->checkDevice(0x37))
  {
    $i2c->selectDevice(0x37);

    my $tempreg = $i2c->readWordData(0);
    my $temphi = $tempreg & 0xFF;
    my $templo = ($tempreg >> 8) & 0xFF;

    #print "temp register: $tempreg $temphi $templo\n";

    my $tempswap = ($temphi << 8) + $templo;
    #printf "%04x - %04x\n", $tempreg, $tempswap;
    my $temp = ($tempswap >> 5) / 8;

    #print "temperature: $temp\n";
    $sensdata{VALUE} = $temp;
    $sensdata{VALID} = 1;
  }
else
  {
    $sensdata{VALID} = 0;
    $sensdata{FAULTS} = 'bus';
  }

for my $k(sort keys %sensdata)
  {
    print "$k=$sensdata{$k}\n";
  }
