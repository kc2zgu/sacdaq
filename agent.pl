#!/usr/bin/perl

use strict;

use Getopt::Std;

use FindBin;
use lib "$FindBin::Bin/lib";

use SensInstance;
use SensLog;

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

my $log = SensLog->new("logs");

while (1)
  {
    my $runtime = time;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime $runtime;
    my $logpath = sprintf("%04d-%02d-%02d.%02d.log", $year+1900, $mon+1, $mday, $hour);
    $log->open($logpath);

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
		eval
                {
		    print "Collecting $sensor->{name}\n";
                    my $report = $sensor->report($runtime);

                    for my $k(sort keys %$report)
                    {
                        print "$k: $report->{$k}\n";
                    }
                    $log->write_report($report);
                };
		if ($@)
                {
		    print "Report failed: $@\n";
                }
            }
        }
	else
        {
	    print "Sensor $sensor->{name} not enabled\n";
        }
    }
    sleep 5;
}
