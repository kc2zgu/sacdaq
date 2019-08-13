#!/usr/bin/perl

use strict;

use Getopt::Std;
use DateTime;

use FindBin;
use lib "$FindBin::Bin/lib";

use SensInstance;
use SensDB;
use TimeSync;
use RepQueue;
use HTTP::Tiny;

my $logfd;

sub logmsg {
    my $msg = shift;

    if (defined $logfd)
    {
        local $| = 1;
        print $logfd "[AGENT] $msg\n";
    }
    else
    {
        print STDERR "[AGENT] $msg\n";
    }
}

my $blinkserv = "http://localhost:8182";
my $ledpin = 13;
my $http = HTTP::Tiny->new;
sub led_open {
    logmsg "Activating LED GPIO";
    $http->get("$blinkserv/open?pin=$ledpin");
}
sub led_on {
    logmsg "LED On";
    $http->get("$blinkserv/set?pin=$ledpin&value=1");
}
sub led_off {
    logmsg "LED Off";
    $http->get("$blinkserv/set?pin=$ledpin&value=0");
}

SensInstance::setlog(\&logmsg);

my %opts;
getopts('r:bl:', \%opts);

my $root = $FindBin::Bin;
if ($opts{r})
{
    $root = $opts{r};
}

logmsg "SACDaq agent starting";
logmsg "Root directory: $root";

my @sensors;
logmsg "Populating sensors";

opendir my $sensorsd, "$root/sensors.d";
while (my $conf = readdir $sensorsd)
{
    if ($conf =~ /\.yaml$/)
    {
        logmsg "Reading $conf";
        my $instance = SensInstance->new("sensors.d/$conf");
        if (defined $instance)
        {
            push @sensors, $instance;
            logmsg "Loaded $instance->{name}";
        }
        else
        {
            logmsg "Invalid definition in $conf";
        }
    }
}

unless (-d "$root/logs")
{
    logmsg "Creating log directory $root/logs";
    mkdir "$root/logs";
}

if ($opts{l})
{
    open $logfd, '>>', $opts{l};
}

my $db;
sub log_start {
    my $dbfile = "logs/sensordata.sqlite";
    logmsg "Opening SQLite satabase $dbfile";
    if (-f $dbfile)
    {
        $db = SensDB->connect("dbi:SQLite:$dbfile");
    }
    else
    {
        $db = SensDB->connect("dbi:SQLite:$dbfile");
        $db->deploy;
    }
}

sub log_append {
    my $report = shift;
    if (defined $db)
    {
        my $sensordef = $db->resultset('Sensordef')->find_or_create({name => $report->{'SENSOR-NAME'},
                                                                     uuid => $report->{'SENSOR-UUID'},
                                                                     dimension => $report->{'DIMENSION'}},
                                                                    {key => 'uuid_unique'});
        my $time = $report->{TIME};
        my $result = $report->{RESULT} eq 'SUCCESS' ? 1 : 0;
        my $exts = join ';', map {my ($k)=/^X-(.*)$/;"$k=$report->{$_}"} sort grep {/^X-/} keys %$report;
        my $dbreport = $sensordef->create_related(reports => {time => $time,
                                                              result => $result,
                                                              valid => $report->{VALID},
                                                              dimension => $report->{DIMENSION},
                                                              value => $report->{VALUE},
                                                              unit => $report->{UNIT},
                                                              driver => $report->{DRIVER},
                                                              faults => $report->{FAULTS} // 'none',
                                                              extensions => $exts});
    }
}

log_start();

led_open();

TimeSync::timesync_wait();

logmsg "Time synchronized";

my $repq = RepQueue->new;
$repq->{db} = $db;

while (1)
{
    my $runtime = time;
    my $dt = DateTime->from_epoch(epoch => $runtime);

    my $led = 0;

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
		if ($led == 0)
		{
			led_on();
			$led = 1;
		}
		eval
                {
		    logmsg "Collecting $sensor->{name}";
                    my $report = $sensor->report($dt, $root);

                    logmsg join '; ', map {"$_=$report->{$_}"} sort keys %$report;

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
                };
		if ($@)
                {
		    logmsg "Report failed: $@";
                }
            }
        }
	else
        {
	    # logmsg "Sensor $sensor->{name} not enabled";
        }
    }
    $repq->flush();
	led_off() if $led == 1;
    sleep 2;
}
