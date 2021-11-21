package SensInstance;

use strict;

use YAML qw/LoadFile/;
use IPC::Run qw/run/;
use File::Slurp;
use UUID::Tiny ':std';
use FindBin;

my $logsub;

sub logmsg {
    my $msg = shift;
    if (ref $logsub)
    {
        $logsub->($msg);
    }
    else
    {
        print STDERR "[LOG] $msg\n";
    }
}

sub setlog {
    $logsub = shift;
}

sub new {
    my ($class, $conf) = @_;

    my $self = LoadFile($conf);

    return undef unless (defined $self->{driver} && defined $self->{name});

    $self->{args} = [] unless exists $self->{args};

    my $uuid;
    eval {$uuid = read_file("sensors.d/$self->{name}.uuid")};
    chomp $uuid;
    if (defined $uuid && is_uuid_string($uuid))
    {
        $self->{uuid} = $uuid;
    }
    else
    {
        logmsg "No UUID found, creating a new one";
        $uuid = create_uuid_as_string();
        $self->{uuid} = $uuid;
        write_file("sensors.d/$self->{name}.uuid", "$uuid\n");
    }
    logmsg "UUID: $self->{uuid}";

    bless $self, $class;
}

sub new_direct {
  my ($class, $driver, @args) = @_;

  my $self = {driver => $driver, args => [@args]};

  bless $self, $class;
}

sub report {
    my ($self, $time, $datadir) = @_;

    my $drvpath = "$FindBin::Bin/drivers";
    my $libpath = "$FindBin::Bin/lib";
    my $driver = $self->{driver};
    my $logfile = "$datadir/logs/$driver.log";

    my $drvfile = "$drvpath/$driver.pl";
    my %repvalues = ('SENSOR-NAME' => $self->{name}, 'SENSOR-UUID' => $self->{uuid}, TIME => $time);

    logmsg "About to run $drvfile";
    if (-x $drvfile)
    {
        my $repdata;
        run ["$drvfile", @{$self->{args}}, defined ($datadir) ? "log=$logfile" : ()], \undef, \$repdata,
          init => sub { $ENV{PERL5LIB} = "$libpath:$ENV{PERL5LIB}"; };
        $repvalues{RESULT} = 'SUCCESS';
        for my $sensline (split "\n", $repdata)
        {
            my ($k, $v) = split /=/, $sensline;
            $repvalues{$k} = $v;
        }
        $repvalues{RESULT} = 'FAIL' unless defined ($repvalues{VALID});
    }
    else
    {
        logmsg "Driver is not executable or does not exist";
        $repvalues{RESULT} = 'FAIL';
    }
    return \%repvalues;
}

sub clear_samples {
    my $self = shift;

    $self->{samples} = [];
}

sub push_sample {
    my ($self, $report) = @_;

    push @{$self->{samples}}, $report;
    my $n = $self->sample_count;
    logmsg "Pushed sample $report->{VALUE} (n=$n)";
}

sub sample_count {
    my $self = shift;
    return scalar @{$self->{samples}};
}

sub get_average {
    my $self = shift;

    my @samples = @{$self->{samples}};
    if (@samples == 0)
    {
	logmsg "No samples to average";
	return undef;
    }
    elsif (@samples == 1)
    {
	logmsg "One sample average: $samples[0]->{VALUE}";
	return $samples[0];
    }
    else
    {
	my $avgcount = 0;
	my $total = 0;
	my $report = {%{$samples[0]}};
	for my $sample(@samples)
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
	    logmsg "Average of $avgcount samples: $avgval";
	    $report->{VALUE} = $avgval;
	    $report->{'X-AVERAGE'} = $avgcount;
	    $report->{VALID} = 1;
	    return $report;
	}
	else
	{
	    logmsg "No valid samples to average";
	    $report->{VALID} = 0;
	    $report->{VALUE} = 0;
	    return $report;
	}
    }
}


1;
