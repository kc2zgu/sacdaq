#!/usr/bin/perl

use strict;

use SensDrv;

use Device::Chip::BME280;
use Device::Chip::Adapter::LinuxKernel;

my $sensor = SensDrv->new('BME280', 0.02,
			  bus => 1, chipaddr => '0x77', mode => 'TEMP');

my $bus = $sensor->get('bus');
my $addr = hex $sensor->get('chipaddr');
my $mode = $sensor->get('mode');

my $chip = Device::Chip::BME280->new;
$chip->mount(Device::Chip::Adapter::LinuxKernel->new(i2c_bus => "/dev/i2c-$bus"))->get;

$chip->update();

if ($mode eq 'TEMP')
{
    my $temp = $chip->get_temperature()->get;
    $sensor->set_unit('TEMP', 'Celsius');
    $sensor->set_value(sprintf('%.2f', $temp));
    $sensor->set_extension(PRECISION => 0.01);

    $sensor->report();
}
elsif ($mode eq 'RH')
{
    my $hum = $chip->get_humidity()->get;
    $sensor->set_unit('RH', 'Percent');
    $sensor->set_value(sprintf('%.2f', $hum));
    $sensor->set_extension(PRECISION => 0.01);

    $sensor->report();
}
elsif ($mode eq 'PRES')
{
    my $pres = $chip->get_pressure()->get;
    $sensor->set_unit('PRES', 'Pascal');
    $sensor->set_value(sprintf('%.2f', $pres));
    $sensor->set_extension(PRECISION => 0.01);

    $sensor->report();
}
