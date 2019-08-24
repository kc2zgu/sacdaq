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
    my $period = $c->req->param('period') // 'day';

    my @intervals;
    my ($trunc, $count, $interval, $span);

    if ($period eq 'day')
    {
	$trunc = 'hour';
	$count = 24;
	$interval = DateTime::Duration->new(hours => 1);
	$span = DateTime::Duration->new(minutes => 30);
    }
    if ($period eq 'week')
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
    $c->log->debug("Most recent: $last_time");
    my $trunc_time = $last_time->truncate(to => $trunc);
    $c->log->debug("Most recent period: $trunc_time");
    for (1..$count)
    {
	my $range_start = $trunc_time - $span;
	my $range_end = $trunc_time + $span;
	$c->log->debug("Next range: $range_start - $range_end ($trunc_time)");
	push @intervals, [$trunc_time->clone, $range_start, $range_end];
	$trunc_time -= $interval;
    }

    for my $interval(@intervals)
    {
	$c->log->debug("Looking up $interval->[0]");
	my @reports = $s->search_related('reports', {time => {-between => [$interval->[1], $interval->[2]]}},
					 {order_by => {-desc => 'time'}});
	
	my $stat = Statistics::Descriptive::Full->new();
	for my $rep (@reports)
	{
	    my $t = $rep->time;
	    $stat->add_data($rep->value);
	}
	push @$interval, $stat->mean, $stat->min, $stat->max;
	$c->log->debug("Average: $interval->[3]");
	$c->log->debug("Min: $interval->[4]");
	$c->log->debug("Max: $interval->[5]");
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
