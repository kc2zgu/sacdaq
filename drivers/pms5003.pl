#!/usr/bin/perl

use strict;
use v5.32;

use SensDrv;
use IO::Termios;

my %channels  = ('PM01' => 4, 'PM25' => 5, 'PM10' => 6);

my $sensor = SensDrv->new('PMS5003', 0.01,
			  port => '/dev/ttyS0', channel => 'PM25');

my $serial = IO::Termios->open($sensor->get('port'), '9600,8,n,1');
unless (defined $serial)
{
    $sensor->set_fault('bus');
    $sensor->report;
    exit;
}

$serial->cfmakeraw;

# skip any old buffered data up to 1K
my $dummy;
$serial->sysread($dummy, 1024);

my $sync = 0;
# read a byte at a time until the sync symbol is seen
while ($sync != 0x424d)
{
    my $byte;
    $serial->sysread($byte, 1);
    $sync = (($sync << 8) | ord($byte)) & 0xffff;
}

# read 2 bytes to parse the frame length
my $frame;
$serial->sysread($frame, 1, 0);
$serial->sysread($frame, 1, 1);

my $length = ord(substr($frame,0,1)) << 8 | ord(substr($frame, 1, 1));

# give up if the length seems invalid
if ($length < 256)
{
    # read the rest of the frame
    while (length $frame < $length + 2)
    {
        my $readlen = ($length + 2 - length $frame);
        my $count = $serial->sysread($frame, $readlen, length $frame);
    }

    # extract each of the 16-bit data words
    my @data_words;

    for my $i(0..(length($frame)/2)-1)
    {
        my $word = ord(substr($frame, $i*2, 1)) << 8 | ord(substr($frame, $i*2+1, 1));
        push @data_words, $word;
    }

    # report the value from the requested channel
    my $channel = $sensor->get('channel');

    $sensor->set_value($data_words[$channels{$channel}]);
    $sensor->set_unit('PMAT', 'ugm3');
    $sensor->report;
}
