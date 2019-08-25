#!/usr/bin/perl

use strict;

use FindBin;
use lib "$FindBin::Bin/lib";
use SensDB;
use Plot;
use DateTime;
use DateTime::Format::ISO8601;

my $db = SensDB->connect("dbi:Pg:host=moclus-pg.local;user=sacdaq;dbname=sacdaq;password=sacdaq");

my ($start, $end, @uuids) = @ARGV;

my $dtformat = DateTime::Format::ISO8601->new;
my $startdt_local = $dtformat->parse_datetime($start);
my $enddt_local = $dtformat->parse_datetime($end);

my $plot = Plot->new(start => $startdt_local, end => $enddt_local,
                     timezone => DateTime::TimeZone->new(name => 'local'),
                     unit => 'Fahrenheit');

my @names;

for my $uuid(@uuids)
{
    my ($sensor) = $db->resultset('Sensordef')->find({uuid => $uuid});

    my $sn = $plot->add_series($sensor->name);
    push @names, $sensor->name;
    $plot->load_data($sn, $sensor);
}

my $plotimg = $plot->plot;

unless (defined $plotimg)
{
    die "Plot failed\n";
}

print "Output file: $plotimg\n";

my $newfile = "plot_" . join('_', @names) . ".png";
rename $plotimg, $newfile;
print "Saved as $newfile\n";
