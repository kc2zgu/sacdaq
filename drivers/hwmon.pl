#!/usr/bin/perl

use strict;
use v5.32;

use SensDrv;
use Path::Tiny;

# driver for Linux hardware monitor devices (CPU temp and voltage sensors, fans, etc)

my $sensor = SensDrv->new('hwmon', 0.01,
			  class => 'hwmon', device => 'hwmon0', input => 'temp1');

my $sysfs_dir = path('/sys/class', $sensor->get('class'), $sensor->get('device'));

# check if the device directory exists under sysfs
unless ($sysfs_dir->is_dir)
{
    $sensor->set_fault('nodev');
    $sensor->report;
    exit;
}

# look up the device name if it exists
my $hwmon_name_file = $sysfs_dir->child('name');
if ($hwmon_name_file->exists)
{
    my $hwmon_name = $hwmon_name_file->slurp;
    chomp $hwmon_name;
    $sensor->set_extension(NAME => $hwmon_name);
}

# read the input value, faile if it does not exist
my $input_file = $sysfs_dir->child($sensor->get('input') . '_input');
unless ($input_file->exists)
{
    $sensor->set_fault('noinput');
    $sensor->report;
    exit;
}

my $input = $input_file->slurp;
chomp $input;

# convert and add unit metadata for known sensor types
if ($sensor->get('input') =~ /^temp/)
{
    $sensor->set_unit('TEMP', 'Celsius');
    $input /= 1000;
}
elsif ($sensor->get('input') =~ /^in/)
{
    $sensor->set_unit('VOLT', 'Volt');
    $input /= 1000;
}
elsif ($sensor->get('input') =~ /^cur/)
{
    $sensor->set_unit('CURR', 'Amp');
    $input /= 1000;
}
elsif ($sensor->get('input') =~ /^power/)
{
    $sensor->set_unit('POWR', 'Watt');
    $input /= 1000;
}

$sensor->set_value($input);

# look up an input label if it exists
my $label_file = $sysfs_dir->child($sensor->get('input') . '_label');
if ($label_file->exists)
{
    my $label = $label_file->slurp;
    chomp $label;
    $sensor->set_extension(LABEL => $label);
}

$sensor->report;
