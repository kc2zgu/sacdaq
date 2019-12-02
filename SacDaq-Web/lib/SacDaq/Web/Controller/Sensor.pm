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

sub summary :Chained('sensor') :Args(0) {
    my ($self, $c) = @_;

    my $s = $c->stash->{sensordef};
    my $period = $c->req->param('period') // '1d';

    my @intervals;
    my ($trunc, $count, $interval, $span);

    $c->stash->{period} = $period;

    if ($period eq '6h')
    {
	$trunc = 'hour';
	$count = 12;
	$interval = DateTime::Duration->new(minutes => 30);
	$span = DateTime::Duration->new(minutes => 15);
    }
    elsif ($period eq '1d')
    {
	$trunc = 'hour';
	$count = 24;
	$interval = DateTime::Duration->new(hours => 1);
	$span = DateTime::Duration->new(minutes => 30);
    }
    elsif ($period eq '7d')
    {
	$trunc = 'day';
	$count = 7;
	$interval = DateTime::Duration->new(days => 1);
	$span = DateTime::Duration->new(hours => 12);
    }

    my ($lastrep) = $s->search_related('reports', {},
				       {order_by => {-desc=>'time'},
					rows => 1});
    my $last_time = $lastrep->time;
    my $trunc_time = $last_time->truncate(to => $trunc);
    for (1..$count)
    {
	my $range_start = $trunc_time - $span;
	my $range_end = $trunc_time + $span;
	push @intervals, [$trunc_time->clone, $range_start, $range_end];
	$trunc_time -= $interval;
    }

    for my $interval(@intervals)
    {
	my @reports = $s->search_related('reports', {time => {-between => [$interval->[1], $interval->[2]]}},
					 {order_by => {-desc => 'time'}});
	
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
