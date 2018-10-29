#!/usr/bin/perl

use strict;

use SensDrv;

use Device::LinuxSPI::Tiny;

my $sensor = SensDrv->new('MAX6675 thermocouple amplifier', 0.01,
                         bus => 0, cs => 0);

my $bus = $sensor->get('bus');
my $cs = $sensor->get('cs');
$sensor->set_unit('TEMP', 'Celsius');

my $spidev = Device::LinuxSPI::Tiny->new("/dev/spidev$bus.$cs");

if (defined $spidev)
{
    $spidev->set_mode(0);
    $spidev->set_speed(1000000);
    my @bytes = $spidev->transfer_bytes(0, 0);
    if (@bytes == 2)
    {
        $sensor->logmsg(sprintf "raw temperature register: 0x%02x%02x", @bytes);
        if ($bytes[1] & 0x4)
        {
            $sensor->logmsg("Input open");
            $sensor->set_fault('open');
        }
        else
        {
            my $temp = ((($bytes[0] << 8) + $bytes[1]) >> 3) / 4;
            $sensor->set_value($temp);
            $sensor->set_extension(PRECISION => 0.25);
        }
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
