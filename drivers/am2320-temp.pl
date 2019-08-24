#!/usr/bin/perl

use strict;

use SensDrv;

use Device::I2C;
use Fcntl;

my $sensor = SensDrv->new('AM2320 Temperature', 0.01,
                          bus => 1, chipaddr => '0x5c');

my $bus = $sensor->get('bus');
my $chip = hex $sensor->get('chipaddr');

my $i2c = Device::I2C->new("/dev/i2c-$bus", O_RDWR);

$sensor->logmsg(sprintf "i2c device: 0x%02x", $chip);

sub am2320_read {
  my ($i2c, $reg) = @_;

  my $wrbuf = pack('C*', 0x03, $reg, 2);
  $i2c->syswrite($wrbuf);

  my $rdbuf;
  $i2c->sysread($rdbuf, 6);
  my @rdbytes = unpack('C*', $rdbuf);

  return ($rdbytes[2] << 8) + $rdbytes[3];
}

$sensor->set_unit('TEMP', 'Celsius');

$i2c->selectDevice($chip);
$i2c->writeByte(0x00);

if ($i2c->checkDevice($chip))
  {
    my $temp = am2320_read($i2c, 0x02);
    
    $sensor->logmsg(sprintf "temp register: %04x", $temp);

    if ($temp & 0x8000)
      {
	$temp = -(65535 - $temp);
      }

    $sensor->set_value($temp / 10);
    $sensor->set_extension(PRECISION => 0.1);
  }
else
  {
    $sensor->set_fault('bus');
  }

$sensor->report;
