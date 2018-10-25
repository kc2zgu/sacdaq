#!/usr/bin/perl

use strict;

use SensDrv;

use Device::I2C;
use Fcntl;

my $sensor = SensDrv->new('LM75 temperature', 0.01,
                          bus => 1, chipaddr => '0x48', bits => 9);

my $bus = $sensor->get('bus');
my $chip = hex $sensor->get('chipaddr');
my $bits = $sensor->get('bits');

my $i2c = Device::I2C->new("/dev/i2c-$bus", O_RDWR);

$sensor->logmsg(sprintf "i2c device: 0x%02x", $chip);
$sensor->set_unit('TEMP', 'Celsius');

if ($i2c->checkDevice($chip))
{
    $i2c->selectDevice($chip);

    my $tempreg = $i2c->readWordData(0);
    my $temphi = $tempreg & 0xFF;
    my $templo = ($tempreg >> 8) & 0xFF;

    my $tempswap = ($temphi << 8) + $templo;
    $sensor->logmsg(sprintf "raw temperature register: 0x%04x 0b%016b", $tempswap, $tempswap);
    my $temp;

    if ($bits >= 8 && $bits <= 16)
    {
        my $shift = 16 - $bits;
        my $top = 2 ** $bits;
        my $fraction = 2 ** ($bits - 8);

        my $tempint = $tempswap >> $shift;
        $tempint = -($top - $tempint) if ($tempswap & 0x8000);
        $sensor->set_value($tempint / $fraction);
        $sensor->set_extension(PRECISION => 1/$fraction);
    }
    else
    {
        $sensor->set_fault('config');
    }
  }
else
{
    $sensor->set_fault('bus');
}

$sensor->report;
