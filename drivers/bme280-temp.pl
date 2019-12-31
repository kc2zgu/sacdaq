#!/usr/bin/perl

use strict;

use SensDrv;

use Device::I2C;
use Fcntl;

my $sensor = SensDrv->new('BME280 Temperature', 0.01,
			  bus => 1, chipaddr => '0x77');

my $bus = $sensor->get('bus');
my $chip = hex $sensor->get('chipaddr');

my $i2c = Device::I2C->new("/dev/i2c-$bus", O_RDWR);

$sensor->set_unit('TEMP', 'Celsius');

$i2c->selectDevice($chip);

if ($i2c->checkDevice($chip))
{
    
    my %regs = (dig_T1 =>   [0x88, 2],
		dig_T2 =>   [0x8A, 2],
		dig_T3 =>   [0x8C, 2],
		dig_P1 =>   [0x8E, 2],
		dig_P2 =>   [0x90, 2],
		dig_P3 =>   [0x92, 2],
		dig_P4 =>   [0x94, 2],
		dig_P5 =>   [0x96, 2],
		dig_P6 =>   [0x98, 2],
		dig_P7 =>   [0x9A, 2],
		dig_P8 =>   [0x9C, 2],
		dig_P9 =>   [0x9E, 2],
		dig_H1 =>   [0xA1, 1],
		dig_H2 =>   [0xE1, 2],
		dig_H3 =>   [0xE3, 1],
		dig_H4 =>   [0xE4, 2],
		dig_H5 =>   [0xE6, 2],
		dig_H6 =>   [0xE8, 1],
		temp_msb => [0xFA, 1],
		temp_lsb => [0xFB, 1],
		temp_xsb => [0xFC, 1],
		pres_msb => [0xF7, 1],
		pres_lsb => [0xF8, 1],
		pres_xsb => [0xF9, 1],
		hum_msb =>  [0xFD, 1],
		hum_lsb =>  [0xFE, 1],
	);

    $i2c->writeByteData(0xF4, 0x35);

    my %values;

    for my $reg(sort {$regs{$a}->[0] <=> $regs{$b}->[0]} keys %regs)
    {
	my @data = $i2c->readBlockData(@{$regs{$reg}});
	my $value = 0;
	while (@data)
	{
	    $value = ($value << 8) + pop @data;
	}
	#print "$reg: $value @data \n";
	$values{$reg} = $value;
    }

    sub u16s16 { $_[0] = -65536 + $_[0] if ($_[0] > 32767) }
    sub u8s8 { $_[0] = -256 + $_[0] if ($_[0] > 127) }

    for (qw/T2 T3 P2 P3 P4 P5 P6 P7 P8 P9 H2 H4 H5/)
    {
	u16s16($values{"dig_$_"});
	#print "signed $_: $values{dig_$_}\n";
    }
    u8s8($values{dig_H6});

    my $t_fine;
    
    sub compensate_temp {
	my $temp_raw = shift;
	my $var1 = $temp_raw / 16384.0 - $values{dig_T1} / 1024.0;
	$var1 = $var1 * $values{dig_T2};
	my $var2 = $temp_raw / 131072.0 - $values{dig_T1} / 8192.0;
	$var2 = ($var2 * $var2) * $values{dig_T3};
	$t_fine = $var1 + $var2;
	my $temp_cal = $t_fine / 5120.0;

	return $temp_cal;
    }

    my $temp_raw = ($values{temp_msb} << 12) + ($values{temp_lsb} << 4) + ($values{temp_xsb} >> 4);
    #my $temp_hi = $temp_raw + 8;
    #my $temp_lo = $temp_raw - 8;
    #my $temp_dif = compensate_temp($temp_hi) - compensate_temp($temp_lo);
    my $temp_cal = compensate_temp($temp_raw);

    #print "Temperature raw ADC: $temp_raw\n";
    #print "Temperature: $temp_cal (+/- $temp_dif)\n";
    #print "t_fine: $t_fine\n";

    $sensor->set_value($temp_cal);
    $sensor->set_extension(PRECISION => 0.01);
}
else
{
    $sensor->set_fault('bus');
}

$sensor->report;
