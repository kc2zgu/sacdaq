#!/usr/bin/perl

use strict;

use SensDrv;

use Device::Chip::Adapter::LinuxKernel;

my $sensor = SensDrv->new('AHT20', 0.01,
			  bus => 1, chipaddr => '0x38', mode => 'TEMP');

my $bus = $sensor->get('bus');
my $addr = hex $sensor->get('chipaddr');
my $mode = $sensor->get('mode');

my $adapter = Device::Chip::Adapter::LinuxKernel->new(i2c_bus => "/dev/i2c-$bus");
my $proto = $adapter->make_protocol('I2C')->get();

$proto->configure(addr => $addr)->get();

$proto->write(pack("C*", 0xBA, 0x80, 0x00))->get();

my $status = ord($proto->write_then_read(pack("C", 0x71), 1)->get());

$proto->write(pack("C", 0xAC, 0x33, 0x00));
sleep 0.5;

my $measurement = $proto->write_then_read("", 7)->get();

my @bytes = unpack("C*", $measurement);

if ($mode eq 'TEMP')
{
    my $temp = $bytes[3] & 0x0F;
    $temp <<= 8;
    $temp += $bytes[4];
    $temp <<= 8;
    $temp += $bytes[5];
    $temp = ($temp * 200 / (2**20)) - 50;

    $sensor->set_unit('TEMP', 'Celsius');
    $sensor->set_value(sprintf('%.2f', $temp));
    $sensor->set_extension(PRECISION => 0.01);

    $sensor->report();
}
elsif ($mode eq 'RH')
{
    my $hum = $bytes[1];
    $hum <<= 8;
    $hum += $bytes[2];
    $hum <<= 4;
    $hum += $bytes[3] >> 4;
    $hum = $hum / (2**20) * 100;

    $sensor->set_unit('RH', 'Percent');
    $sensor->set_value(sprintf('%.2f', $hum));
    $sensor->set_extension(PRECISION => 0.1);

    $sensor->report();
}
