#!/usr/bin/perl

use strict;

use SensDrv;

use Device::I2C;
use Fcntl;

my $sensor = SensDrv->new('ADS1015', 0.01,
                          bus => 1, chipaddr => '0x48');

my $bus = $sensor->get('bus');
my $chip = hex $sensor->get('chipaddr');
my $bits = $sensor->get('bits');

my $i2c = Device::I2C->new("/dev/i2c-$bus", O_RDWR);

$sensor->logmsg(sprintf "i2c device: 0x%02x", $chip);

if ($i2c->checkDevice($chip))
  {
    $i2c->selectDevice($chip);

    $i2c->writeWordData(1, 0x8383 + (7 << 4));

    sleep 1;
    
    my $adcval = $i2c->readWordData(0);
    my $adcswap = (($adcval & 0xFF) << 8) + ($adcval >> 8);
    
    $sensor->set_value(($adcswap >> 4) * .002);
    $sensor->set_extension(RAW => sprintf('%04X', $adcswap));
  }
else
{
    $sensor->set_fault('bus');
}

$sensor->report;
