#!/usr/bin/perl

use strict;

use SensDrv;

use Device::I2C;
use Fcntl;

my $sensor = SensDrv->new('MCP980x temperature', 0.01,
                          bus => 1, chipaddr => '0x1f');

my $bus = $sensor->get('bus');
my $chip = hex $sensor->get('chipaddr');

my $i2c = Device::I2C->new("/dev/i2c-$bus", O_RDWR);

$sensor->logmsg(sprintf "i2c device: 0x%02x", $chip);
$sensor->set_unit('TEMP', 'Celsius');

if ($i2c->checkDevice($chip))
{
    $i2c->selectDevice($chip);

    my $tempreg = $i2c->readWordData(5);
    my $temphi = $tempreg & 0xFF;
    my $templo = ($tempreg >> 8) & 0xFF;

    my $tempswap = ($temphi << 8) + $templo;
    $sensor->logmsg(sprintf "raw temperature register: 0x%04x 0b%016b", $tempswap, $tempswap);
    my $temp;

    my $top = 2 ** 13;
    my $fraction = 2 ** (13 - 8);

    my $tempint = ($tempswap & 0x1fff);
    $tempint = -($top - $tempint) if ($tempint & 0x1000);
    if (($tempint / $fraction) > 150)
    {
        $sensor->set_fault('range');
    }
    else
    {
    $sensor->set_value($tempint / $fraction);
    $sensor->set_extension(PRECISION => 1/$fraction);
    }
}
else
{
    $sensor->set_fault('bus');
}

$sensor->report;
