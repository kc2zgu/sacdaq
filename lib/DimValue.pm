package DimValue;

use strict;

# LABEL => [ name, native_unit ]
my %dims = (
    TEMP => ['Temperature', 'Kelvin'],
    RH => ['Relative Humidity', 'Percent'],
    VOLT => ['Voltage', 'Volt'],
    CURR => ['Current', 'Amp'],
    );

# name => [ dim, symbol, encode, decode ]
my %units = (
    Kelvin => ['TEMP', 'K'],
    Celsius => ['TEMP', 'C', sub { $_[0] - 273.15 }, sub { $_[0] + 273.15 }],
    Fahrenheit => ['TEMP', 'F', sub { $_[0] * 1.8 - 459.67 }, sub { ($_[0] + 459.67) / 1.8 }],
    Rankine => ['TEMP', 'R', sub { $_[0] * 1.8 }, sub { $_[0] / 1.8 }],
    Percent => ['RH', '%'],
    Volt => ['VOLT', 'V'],
    Amp => ['CURR', 'A'],
    );

sub new {
    my ($class, @args) = @_;

    my $self = { @args };

    if (exists $units{$self->{UNIT}})
    {
	my $udim = $units{$self->{UNIT}}->[0];

	if ($self->{DIMENSION} ne $udim)
	{
	    $self->{DIMENSION} = $udim;
	}
    }

    bless $self, $class;
}

sub _format_value {
    my ($value, $unit, $digits) = @_;

    my $sym = $units{$unit}->[1] // $unit;

    return sprintf("%.${digits}f %s", $value, $units{$unit}->[1]);
}

sub format {
    my $self = shift;

    my $value = $self->{VALUE};
    my $unit = $self->{UNIT};
    my $digits = 2;

    return _format_value($value, $unit, $digits);
}

sub convert {
    my ($self, $unit) = @_;

    unless (exists $units{$unit})
    {
	die "Unit $unit not defined";
    }

    my $dim = $self->{DIMENSION};
    unless ($units{$unit}->[0] eq $dim)
    {
	die "Can't convert $dims{$dim}->[0] to $dims{$units{$unit}->[0]}->[0] unit $unit";
    }

    my $nu = $dims{$dim}->[1];
    my $nv = ($self->{UNIT} eq $nu) ? $self->{VALUE} : $units{$self->{UNIT}}->[3]->($self->{VALUE});
    
    my $cv = $units{$unit}->[2]->($nv);
    return $cv;
}

sub convert_format {
    my ($self, $unit) = @_;

    return _format_value($self->convert($unit), $unit, 2);
}

1;
