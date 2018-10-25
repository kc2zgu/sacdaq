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
    if ($bits == 9)
    {
        my $tempint = $tempswap >> 7;
        $tempint = -(512 - $tempint) if ($tempswap & 0x8000);
        $sensor->set_value($tempint / 2);
        $sensor->set_extension(PRECISION => 0.5);
    }
    if ($bits == 10)
    {
        my $tempint = $tempswap >> 6;
        $tempint = -(1024 - $tempint) if ($tempswap & 0x8000);
        $sensor->set_value($tempint / 4);
        $sensor->set_extension(PRECISION => 0.25);
    }
    elsif ($bits == 11)
    {
        my $tempint = $tempswap >> 5;
        $tempint = -(2048 - $tempint) if ($tempswap & 0x8000);
        $sensor->set_value($tempint / 8);
        $sensor->set_extension(PRECISION => 0.125);
    }
    elsif ($bits == 12)
    {
        my $tempint = $tempswap >> 4;
        $tempint = -(4096 - $tempint) if ($tempswap & 0x8000);
        $sensor->set_value($tempint / 16);
        $sensor->set_extension(PRECISION => 0.0625);
    }
  }
else
{
    $sensor->set_fault('bus');
}

$sensor->report;
