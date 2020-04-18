package SacDaq::Web::Controller::Sensor;
use Moose;
use namespace::autoclean;

use DateTime;
use DateTime::Duration;
use Statistics::Descriptive;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

SacDaq::Web::Controller::Sensor - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched SacDaq::Web::Controller::Sensor in Sensor.');
}

sub sensor :Chained :CaptureArgs(1) {
    my ($self, $c) = @_;

    my $uuid = $c->req->args->[0];

    $c->log->debug("sensor root req: uuid=$uuid");
    $c->stash->{uuid} = $uuid;
    $c->stash->{current_view} = 'Web_TT';
    if (UUID::Tiny::is_uuid_string($uuid))
    {
	my $db = $c->model('SensDB');
        my $sensordef = $db->resultset('Sensordef')->find({uuid => $uuid});
        if (defined $sensordef)
	{
	    $c->stash->{sensordef} = $sensordef;
	}
	else
	{
	    $c->stash->{'error_string'} = "Sensor $uuid does not exist";
	    $c->detach('error');
	}
    }
    else
    {
	$c->stash->{'error_string'} = "$uuid is not a valid UUID";
	$c->detach('error');
    }
}

sub data :Chained('sensor') :Args(0) {
    my ($self, $c) = @_;

    my $s = $c->stash->{sensordef};

    my @reports = $s->search_related('reports', {}, {order_by => {-desc => 'time'}, rows => 50});
    my $dim = $reports[0]->dimension;
    if ($c->config->{default_units}->{$dim})
    {
	$c->stash->{display_unit} = $c->config->{default_units}->{$dim};
    }
    else
    {
	$c->stash->{display_unit} = $reports[0]->unit;
    }
    $c->stash->{reports} = \@reports;
}

my %summary_interval_defs =
  (
   # key => [count, interval_s, span]
   '6h' => [12, 1800, [-900, 900]],
   '1d' => [24, 3600, [-1800, 1800]],
   '7d' => [7, 86400, [0, 86400]],
  );

sub summary :Chained('sensor') :Args(0) {
    my ($self, $c) = @_;

    my $s = $c->stash->{sensordef};
    my $period = $c->req->param('period') // '1d';

    my @intervals;

    $c->stash->{period} = $period;

    my $last_time;
    if ($c->req->param('end'))
    {
        $last_time = DateTime::Format::ISO8601->parse_datetime($c->req->param('end'));
    } else
    {
        my ($lastrep) = $s->search_related('reports', {},
                                           {order_by => {-desc=>'time'},
                                            rows => 1});
        $last_time = $lastrep->time;
    }
    my $interval_def = $summary_interval_defs{$period};

    my $day = $last_time->clone->truncate(to => 'day');
    my $s_of_day = $last_time->hour * 3600 + $last_time->minute * 60 + $last_time->second;
    #$c->log->debug("current day $last_time: $day + $s_of_day s");
    my $interval_n = int($s_of_day / $interval_def->[1]) + 1;
    my $interval_step = DateTime::Duration->new(seconds => $interval_def->[1]);
    my $nspan = DateTime::Duration->new(seconds => $interval_def->[2]->[0]);
    my $pspan = DateTime::Duration->new(seconds => $interval_def->[2]->[1]);
    my $int_label = $day + ($interval_step * $interval_n);

    for (1..$interval_def->[0])
    {
        #$c->log->debug($int_label);
        push @intervals, [$int_label->clone, $int_label + $nspan, $int_label + $pspan];
        $int_label -= $interval_step;
    }

    for my $interval(@intervals)
    {
	my @reports = $s->search_related('reports', {time => {-between => [$interval->[1], $interval->[2]]}},
					 {order_by => {-desc => 'time'}});
	if (@reports > 0)
        {
            my $dim = $reports[0]->dimension;
            if ($c->config->{default_units}->{$dim})
            {
                $c->stash->{display_unit} = $c->config->{default_units}->{$dim};
            }
            else
            {
                $c->stash->{display_unit} = $reports[0]->unit;
            }
            my $stat = Statistics::Descriptive::Full->new();
            for my $rep (@reports)
            {
                my $t = $rep->time;
                $stat->add_data($rep->value);
            }
            push @$interval,
                map {DimValue->new(DIMENSION => $dim, UNIT => $reports[0]->unit, VALUE => $_)} (
                    $stat->mean,
                    $stat->min,
                    $stat->max);
        }
        else
        {
            # no data
        }
    }
    $c->stash->{intervals} = \@intervals;
}

sub error :Private {
    my ($self, $c) = @_;

    $c->stash->{template} = 'sensor/error.tt';
}

=encoding utf8

=head1 AUTHOR

A clever guy

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
