#!/usr/bin/perl

use strict;

use Getopt::Std;
use DateTime;
use POE;
use Path::Tiny;
use YAML qw/LoadFile/;

use FindBin;
use lib "$FindBin::Bin/lib";

use SensInstance;
use SensDB;
use TimeSync;
use RepQueue;

# log message function

sub logmsg {
    print "[sacdaq] $_[0]\n";
}

SensInstance::setlog(\&logmsg);

# read master config

my %opts;
getopts('r:bl:c:', \%opts);

my $root = path($FindBin::Bin);
if ($opts{r})
{
    $root = path($opts{r});
}

my $confname = 'sacdaq.conf';
if ($opts{c})
{
    $confname = $opts{c};
}
my $config = LoadFile($root->child($confname));

# read sensors

my @sensors;
my $sensordir = $root->child('sensors.d');

for my $yaml($sensordir->children(qr/\.yaml$/))
{
    logmsg "found sensor YAML: $yaml";
    logmsg "Reading $yaml";
    my $instance = SensInstance->new($yaml);
    if (defined $instance)
    {
        push @sensors, $instance;
        logmsg "Loaded $instance->{name}";
    }
    else
    {
        logmsg "Invalid definition in $yaml";
    }
}

# wait for time sync

my $use_timesync = 1;

# open database

my $db;
if ($config->{database}->{driver} eq 'sqlite')
{
    my $dbfile = $config->{database}->{path};
    my $deploy = 0;
    if (!path($dbfile)->is_file)
    {
        logmsg "deploy database to $dbfile";
        $deploy = 1;
    }
    logmsg "opening SQLite $dbfile";
    $db = SensDB->connect("dbi:SQLite:$dbfile");
    if ($deploy == 1)
    {
        $db->deploy;
    }
}
else
{
    logmsg "fatal: no valid database specified";
    die;
}

my $repq = RepQueue->new;
$repq->{db} = $db;

# POE state functions

sub _start {
    logmsg "main session starting";
    if ($use_timesync) {
        $_[KERNEL]->yield('check_timesync');
    } else
    {
        $_[KERNEL]->yield('main_loop');
    }
}

sub main_loop {
    #logmsg "in main loop";

    my $runtime = time;
    my $dt = DateTime->from_epoch(epoch => $runtime);
    my $report = 0;

    for my $sensor(@sensors)
    {
        if ($sensor->{enabled} == 1)
        {
	    unless (exists $sensor->{time_due})
            {
		$sensor->{time_due} = $runtime;
            }
	    if ($runtime >= $sensor->{time_due})
            {
		$sensor->{time_due} += $sensor->{poll};
                #logmsg "$sensor->{name}";

                $_[KERNEL]->yield(read_sensor => $sensor, $dt);
                $report = 1;
            }
        }
    }

    $_[KERNEL]->delay(main_loop => 2);
    if ($report)
    {
        $_[KERNEL]->yield('flush_reports');
    }
}

sub check_timesync {
    logmsg "checking time sync";

    $_[KERNEL]->delay(main_loop => 5);
}

sub read_sensor {
    my ($sensor, $dt) = @_[ARG0, ARG1];

    logmsg "reading $sensor->{name}";

    my $report = $sensor->report($dt, $root);
    logmsg join '; ', map {"$_=$report->{$_}"} sort keys %$report;

    if ($config->{mqtt}->{enabled})
    {
        if ($report->{VALID})
        {
            $_[KERNEL]->yield(mqtt_publish => $sensor, $report);
        }
    }

    if ($sensor->{average})
    {
        $sensor->push_sample($report);
        if ($sensor->sample_count >= $sensor->{average})
        {
            my $report = $sensor->get_average();
            if (defined $report)
            {
                logmsg "Averaged value: $report->{VALUE}";
                $repq->push($report);
            }
            $sensor->clear_samples();
        }
    }
    else
    {
        logmsg "Saving report";
        $repq->push($report);
    }
}

sub flush_reports {
    #logmsg "Writing reports to database";

    $repq->flush();
}

sub mqtt_publish {

}

POE::Session->create(package_states =>
                     [main => ['_start',
                               'main_loop',
                               'check_timesync',
                               'read_sensor',
                               'flush_reports',
                               'mqtt_publish']
                     ]);

POE::Kernel->run;
