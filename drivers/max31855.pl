#!/usr/bin/perl

use strict;

use SensDrv;

use Device::LinuxSPI::Tiny;

my $sensor = SensDrv->new('MAX31855 thermocouple amplifier', 0.01,
			  bus => 0, cs => 0);

my $bus = $sensor->get('bus');
my $cs = $sensor->get('cs');
$sensor->set_unit('TEMP', 'Celsius');

my $spidev = Device::LinuxSPI::Tiny->new("/dev/spidev$bus.$cs");

if (defined $spidev)
{
    $spidev->set_mode(0);
    $spidev->set_speed(1000000);
    my @bytes = $spidev->transfer_bytes(0, 0, 0, 0);
    if (@bytes == 4)
    {
        $sensor->logmsg(sprintf "SPI data: 0x%02x%02x%02x%02x", @bytes);
        my $reg = ($bytes[0] << 24) + ($bytes[1] << 16) + ($bytes[2] << 8) + $bytes[3];
        $sensor->logmsg(sprintf "raw temperature register: 0x%08x", $reg);
        if ($bytes[1] & 0x1)
        {
            $sensor->logmsg("Fault!");
            my @faults;
            if ($bytes[3] & 0x1)
            {
                push @faults, 'open';
            }
            if ($bytes[3] & 0x2)
            {
                push @faults, 'gnd';
            }
            if ($bytes[3] & 0x4)
            {
                push @faults, 'vcc';
            }
            $sensor->set_fault(join ',', @faults);
        }
        else
        {
            my $temp = ($reg >> 18) & 0x3fff;
            $temp = -(16384 - $temp) if ($temp & 0x2000);
            $temp /= 4;
            $sensor->set_value($temp);
            $sensor->set_extension(PRECISION => 0.25);
        }
        my $localtemp = ($reg >> 4) & 0xfff;
        $localtemp = -(4096 - $localtemp) if ($localtemp & 0x800);
        $localtemp /= 16;
        $sensor->set_extension(COLDJCT => $localtemp);
    }
    else
    {
        $sensor->set_fault('bus');
    }
}
else
{
    $sensor->set_fault('access');
}
$sensor->report;
