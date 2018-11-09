#!/usr/bin/perl

use strict;

use Getopt::Std;
use DateTime;

use FindBin;
use lib "$FindBin::Bin/lib";

use SensInstance;
use SensLog;
use SensDB;
use HTTP::Tiny;

my $blinkserv = "http://localhost:8020";
my $ledpin = 2;
my $http = HTTP::Tiny->new;
sub led_open {
	print "Activating LED GPIO\n";
	$http->get("$blinkserv/open?pin=$ledpin");
}
sub led_on {
	print "LED On\n";
	$http->get("$blinkserv/set?pin=$ledpin&value=1");
}
sub led_off {
	print "LED Off\n";
	$http->get("$blinkserv/set?pin=$ledpin&value=0");
}

print "Sensor agent starting\n";

my @sensors;
print "Populating sensors\n";

opendir my $sensorsd, "sensors.d";
while (my $conf = readdir $sensorsd)
{
    if ($conf =~ /\.yaml$/)
    {
	print "Reading $conf\n";
	my $instance = SensInstance->new("sensors.d/$conf");
        if (defined $instance)
        {
            push @sensors, $instance;
            print "Loaded $instance->{name}\n";
        }
        else
        {
            print "Invalid definition in $conf\n";
        }
    }
}

my $log;
my $db;
sub log_start {
    #$log = SensLog->new("logs");
    my $dbfile = "logs/sensordata.sqlite";
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

sub log_sync {
    my $runtime = shift;

    if (defined $log)
    {
        my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime $runtime;
        my $logpath = sprintf("%04d-%02d-%02d.%02d.log", $year+1900, $mon+1, $mday, $hour);
        $log->open($logpath);
    }
}

sub log_append {
    my $report = shift;
    if (defined $log)
    {
        $log->write_report($report);
    } elsif (defined $db)
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

while (1)
{
    my $runtime = time;
    my $dt = DateTime->from_epoch(epoch => $runtime);
    log_sync($runtime);

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
		    print "Collecting $sensor->{name}\n";
                    my $report = $sensor->report($dt);

                    #for my $k(sort keys %$report)
                    #{
                    #    print "$k: $report->{$k}\n";
                    #}
		    print join ' ', map {"$_=$report->{$_}"} sort keys %$report;
		    print "\n";
                    if ($sensor->{average})
                    {
                        push @{$sensor->{avg_samples}}, $report;
                        if (@{$sensor->{avg_samples}} >= $sensor->{average})
                        {
                            my $avgcount = 0;
                            my $total = 0;
                            for my $sample(@{$sensor->{avg_samples}})
                            {
                                if ($sample->{VALID})
                                {
                                    $total += $sample->{VALUE};
                                    $avgcount++;
                                }
                            }
                            if ($avgcount >= 1)
                            {
                                my $avgval = $total / $avgcount;
                                print "Average of $avgcount samples: $avgval\n";
                                $report->{VALUE} = $avgval;
                                $report->{'X-AVERAGE'} = $avgcount;
                                $report->{VALID} = 1;
                                log_append($report);
                            }
                            else
                            {
                                print "No valid samples to average\n";
                                $report->{VALID} = 0;
                                $report->{VALUE} = 0;
                            }
                            $sensor->{avg_samples} = [];
                        }
                    }
                    else
                    {
                        log_append($report);
                    }
                };
		if ($@)
                {
		    print "Report failed: $@\n";
                }
            }
        }
	else
        {
	    #print "Sensor $sensor->{name} not enabled\n";
        }
    }
	led_off() if $led == 1;
    sleep 5;
}
