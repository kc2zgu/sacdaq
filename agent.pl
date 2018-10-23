#!/usr/bin/perl

use strict;

use IPC::Run qw/run/;
use IO::Handle;

print "Sensor agent starting\n";

my @sensors;
print "Populating sensors\n";

opendir my $sensorsd, "sensors.d";
while (my $conf = readdir $sensorsd)
  {
    if ($conf =~ /\.conf$/)
      {
	my %sensconf;
	print "Reading $conf\n";
	open my $conffd, '<', "sensors.d/$conf";
	while (my $line = <$conffd>)
	  {
	    chomp $line;
	    my ($key, $val) = $line =~ /^(\w+):\s+(.+)$/;
	    print "config: $key = $val\n";
	    $sensconf{$key} = $val;
	  }
	push @sensors, \%sensconf;
      }
  }

my $openlog = '';
my $logfd;

while (1)
  {
    my $runtime = time;
    my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime $runtime;
    my $logpath = sprintf("%04d-%02d-%02d.%02d.log", $year+1900, $mon, $mday, $hour);
    #print "log: $logpath\n";
    if ($logpath ne $openlog)
      {
	print "Opening new log file $logpath\n";
	mkdir 'logs' unless -d 'logs';
	close $logfd if defined $logfd;
	open $logfd, '>>', "logs/$logpath";
	$logfd->autoflush(1);
	$openlog = $logpath;
      }
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
		my @logdata;
		push @logdata, "NAME=$sensor->{name}";
		push @logdata, "TIME=$runtime";
		$sensor->{time_due} += $sensor->{poll};
		eval
		  {
		    print "Collecting $sensor->{name}\n";
		    my $sensout;
		    run ["./$sensor->{agent}"], \undef, \$sensout;
		    push @logdata, "RESULT=success";
		    my ($dim, $val, $unit);
		    for my $sensline (split "\n", $sensout)
		      {
			push @logdata, $sensline;
			my ($k, $v) = split /=/, $sensline;
			$dim = $v if $k eq 'DIMENSION';
			$val = $v if $k eq 'VALUE';
			$unit = $v if $k eq 'UNIT';
		      }
		    print "$dim: $val $unit\n";
		  };
		if ($@)
		  {
		    print "Command failed\n";
		    push @logdata, "RESULT=collect-fail";
		    push @logdata, "ERROR=$@";
		  }
		print $logfd join "\n", @logdata;
		print $logfd "\n\n";
	      }
	  }
	else
	  {
	    print "Sensor $sensor->{name} not enabled\n";
	  }
      }
    sleep 5;
  }
