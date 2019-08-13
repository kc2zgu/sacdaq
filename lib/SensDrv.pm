package SensDrv;

use strict;

my $apiver = '1.0';

my $logfd;
sub logmsg {
    my $msg = shift;
    $msg = shift if ref $msg;
    if (defined $logfd)
    {
        local $| = 1;
        print $logfd "[SENSDRV] $msg\n";
    }
    else
    {
        print STDERR "[SENSDRV] $msg\n";
    }
}

my %calmode =
    (
     'gainoff' => sub {
	 my ($value, $gain, $offset) = @_;

	 return $value * $gain + $offset;
     },
     '2pt' => sub {
	 my ($value, $i1, $o1, $i2, $o2) = @_;

	 return ($o2 - $o1) / ($i2 - $i1) * ($value - $i1) + ($o1 - $i1);
     }
    );

sub new {
    my $class = shift;

    my $drivername = shift;
    my $driverver = shift;
    my %defargs = @_;
    my %runargs;

    for my $runarg(@ARGV)
    {
        my ($key, $value) = split '=', $runarg;
        #logmsg "runtime arg: $key = $value";
        $runargs{$key} = $value;
    }

    my $self = {args => {}, driver => [$drivername, $driverver],
                value => 0, valid => 0, dimension => 'NULL', unit => 'NULL',
                extensions => {}};

    if (defined $runargs{log})
    {
        open $logfd, '>>', $runargs{log};
    }

    logmsg "driver: $self->{driver}->[0]/$self->{driver}->[1]";

    for my $key(sort keys %defargs)
    {
        logmsg "default arg: $key = $defargs{$key}";
        $self->{args}->{$key} = $defargs{$key};
    }

    for my $key(sort keys %runargs)
    {
        logmsg "runtime arg: $key = $runargs{$key}";
        $self->{args}->{$key} = $runargs{$key};
    }

    bless $self, $class;
}

sub get {
    my ($self, $arg) = @_;

    if (exists $self->{args}->{$arg})
    {
        return $self->{args}->{$arg};
    }
    else
    {
        logmsg "$arg not set";
        return undef;
    }
}

sub set_unit {
    my ($self, $dim, $unit) = @_;

    $self->{dimension} = $dim;
    $self->{unit} = $unit;
}

sub _calibrate_value {
    my ($self, $value) = @_;

    my $calfunc = $calmode{$self->{args}->{calmode}};
    my @calparams = split ',', $self->{args}->{calparams};

    return $calfunc->($value, @calparams);
}

sub set_value {
    my ($self, $value) = @_;

    if ($self->{args}->{calmode})
    {
	$value = $self->_calibrate_value($value);
    }

    $self->{value} = $value;
    $self->{valid} = 1;
}

sub set_fault {
    my ($self, $fault) = @_;

    $self->{faults} = $fault;
}

sub set_extension {
    my ($self, $extname, $val) = @_;

    $self->{extensions}->{$extname} = $val;
}

sub report {
    my $self = shift;

    print "API=$apiver\n";
    print "DRIVER=$self->{driver}->[0]/$self->{driver}->[1]\n";
    print "DIMENSION=$self->{dimension}\n";
    print "UNIT=$self->{unit}\n";
    print "VALUE=$self->{value}\n";
    print "VALID=$self->{valid}\n";
    print "FAULTS=$self->{faults}\n" if exists $self->{faults};
    for my $extname(sort keys %{$self->{extensions}})
    {
        print "X-$extname=$self->{extensions}->{$extname}\n";
    }
}

1;
