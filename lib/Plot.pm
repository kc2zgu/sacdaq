package Plot;

use strict;

use Text::CSV_XS qw/csv/;
use File::Temp;
use File::Basename qw/basename/;
use DimValue;

my %formats = (pdf => 'pdfcairo',
               png => 'pngcairo',
               svg => 'svg',
              );

sub new {
    my $class = shift;

    my $self = {start => undef,
                end => undef,
                series => [],
                xscale_label => 'auto',
                xtics => undef,
                timezone => 'UTC',
                dimension => undef,
                unit => undef,
                format => 'png',
                size => [1200,800],
                temproot => '.',
               };

    my %args = @_;
    for my $key(keys %args)
    {
        $self->{$key} = $args{$key} if (exists $self->{$key});
    }

    $self->{tempdir} = File::Temp->newdir(TEMPLATE => "$self->{temproot}/sacdaq-plot-XXXX",
                                          CLEANUP => 1);

    if (defined $self->{start} && defined $self->{end})
    {
        my $timespan = $self->{end}->delta_ms($self->{start});
        my $timespan_min = $timespan->in_units('minutes');
        $self->{timespan_min} = $timespan_min;
    }

    bless $self, $class;
}

sub add_series {
    my ($self, $name) = @_;

    my $sn = @{$self->{series}};

    my $newseries = {name => $name, data => []};

    push @{$self->{series}}, $newseries;
    return $sn;
}

sub _convert_value {
    my ($self, $value) = @_;

    return $value->convert($self->{unit});
}

sub add_reports {
    my ($self, $series, @data) = @_;

    my $dim = $data[0]->[1]->{DIMENSION};
    my $unit = $data[0]->[1]->{UNIT};

    unless (defined $self->{dimension})
    {
        $self->{dimension} = $dim;
    }
    else
    {
        return unless $self->{dimension} eq $dim;
    }

    unless (defined $self->{unit})
    {
        $self->{unit} = $unit;
    }

    push @{$self->{series}->[$series]->{data}},
      map {[$_->[0], $self->_convert_value($_->[1])]} @data;
}

sub load_data {
    my ($self, $series, $sensor) = @_;

    my $start_utc = $self->{start}->clone;
    $start_utc->set_time_zone($self->{timezone});
    $start_utc->set_time_zone('UTC');
    my $end_utc = $self->{end}->clone;
    $end_utc->set_time_zone($self->{timezone});
    $end_utc->set_time_zone('UTC');

    my $rs = $sensor->search_related('reports',
                                   {time => {-between => [$start_utc, $end_utc]}},
                                   {order_by => {-asc => 'time'}});

    while (my $report = $rs->next)
    {
        my $time = $report->time->clone;
        $time->set_time_zone('UTC');
        $time->set_time_zone($self->{timezone});

        $self->add_reports($series, [$time, $report->dimvalue]);
    }
}

sub _write_csv {
    my ($self, $series) = @_;

    my $csvname = $self->{tempdir}->dirname . "/data_$series.csv";

    csv(in => $self->{series}->[$series]->{data}, out => $csvname);

    return basename($csvname);
}

sub _get_time_range {
    my $self = shift;

    my ($start_dt, $end_dt);

    for my $series (@{$self->{series}})
    {
        for my $point(@{$series->{data}})
        {
            unless (defined $start_dt)
            {
                $start_dt = $point->[0];
            }
            else
            {
                $start_dt = $point->[0] if $point->[0] < $start_dt;
            }
            unless (defined $end_dt)
            {
                $end_dt = $point->[0];
            }
            else
            {
                $end_dt = $point->[0] if $point->[0] < $end_dt;
            }
        }
    }

    my $timespan = $end_dt->delta_ms($start_dt);
    my $timespan_min = $timespan->in_units('minutes');

    $self->{start} = $start_dt->clone;
    $self->{end} = $end_dt->clone;
    $self->{timespan_min} = $timespan_min;
}

sub plot {
    my $self = shift;

    my $tempdir = $self->{tempdir}->dirname;
    my $outfile = "plot.$self->{format}";
    my $term = $formats{$self->{format}};

    my @plotscript;

    push @plotscript,
        'set datafile separator comma # use CSV input',
        'set xdata time # X axis is time',
        'set timefmt "%Y-%m-%dT%H:%M:%S" # time format';

    push @plotscript,
        qq(set term $term size $self->{size}->[0],$self->{size}->[1]),
        qq(set output "$tempdir/$outfile");

    push @plotscript,
        'set grid xtics ytics mxtics mytics lt 1 lc "#b0b0b0" lw .7 dt solid, lc "#606060"',
        'set ytics 5',
        'set mytics 5';

    if ($self->{xscale_label} eq 'auto')
    {
        # pick x axis grid based on time interval
        if ($self->{timespan_min} >= 3600)
        {
            $self->{xscale_label} = '%m-%d';
            $self->{xtics} = [86400, 4];
        }
        elsif ($self->{timespan_min} >= 720)
        {
            $self->{xscale_label} = '%m-%d %H';
            $self->{xtics} = [14400, 4];
        }
        elsif ($self->{timespan_min} >= 360)
        {
            $self->{xscale_label} = '%H:%M';
            $self->{xtics} = [3600, 2];
        }
        elsif ($self->{timespan_min} >= 180)
        {
            $self->{xscale_label} = '%H:%M';
            $self->{xtics} = [3600, 4];
        }
        elsif ($self->{timespan_min} >= 75)
        {
            $self->{xscale_label} = '%H:%M';
            $self->{xtics} = [1800, 2];
        }
        else
        {
            $self->{xscale_label} = '%H:%M';
            $self->{xtics} = [900, 15];
        }
    }

    push @plotscript,
        qq(set xtics format "$self->{xscale_label}"),
        qq(set xtics $self->{xtics}->[0]),
        qq(set mxtics $self->{xtics}->[1]);

    my @plots;

    for my $series(0..$#{$self->{series}})
    {
        my $csv = $self->_write_csv($series);
        my $label = $self->{series}->[$series]->{name};

        push @plots,
          qq("$tempdir/$csv" using 1:2 title "$label" with lines);
    }

    push @plotscript,
      qq(plot ["$self->{start}":"$self->{end}"] ) . join(', ', @plots);

    open my $plotfile, '>', "$tempdir/plotcmds.txt";
    for my $line(@plotscript)
    {
        print $plotfile $line . "\n";
    }

    my $ret = system 'gnuplot', "$tempdir/plotcmds.txt";
    if ($ret >> 8 == 0)
    {
        return "$tempdir/$outfile";
    }
    else
    {
        #print STDERR "failed plot commands: ", join("\n", @plotscript);
        return undef;
    }
}

1;
