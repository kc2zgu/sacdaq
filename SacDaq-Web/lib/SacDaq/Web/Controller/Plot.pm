package SacDaq::Web::Controller::Plot;
use Moose;
use namespace::autoclean;

use Plot;
use DateTime;
use DateTime::Format::ISO8601;
use DateTime::Duration;
use IO::File;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

SacDaq::Web::Controller::Plot - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched SacDaq::Web::Controller::Plot in Plot.');
}

sub image :Local {
    my ($self, $c) = @_;

    my @sensors = split /,/, $c->req->param('sensor');
    my $start = $c->req->param('start');
    my $end = $c->req->param('end');
    my $size = $c->req->param('size') // '1200x800';
    
    my $dtformat = DateTime::Format::ISO8601->new;
    my $startdt_local = $dtformat->parse_datetime($start);
    my $enddt_local = $dtformat->parse_datetime($end);

    my $db = $c->model('SensDB');

    my ($dimension, $unit);

    my ($sensordef) = $db->resultset('Sensordef')->find({uuid => $sensors[0]});
    my ($lastrep) = $sensordef->search_related('reports', {},
					 {order_by => {-desc=>'time'},
					  rows => 1});
    $dimension = $lastrep->dimension;
    $unit = $lastrep->unit;
    if ($c->config->{default_units}->{$dimension})
    {
	$unit = $c->config->{default_units}->{$dimension};
    }
    
    my $plot = Plot->new(start => $startdt_local, end => $enddt_local,
			 timezone => $c->stash->{tz},
			 dimension => $dimension, unit => $unit,
			 size => [split 'x', $size]);

    for my $sensor(@sensors)
    {
	my ($sensordef) = $db->resultset('Sensordef')->find({uuid => $sensor});

	my $sn = $plot->add_series($sensordef->name);
	$plot->load_data($sn, $sensordef);
	$c->log->debug("Added series $sn from $sensor");
    }

    if (defined $plot->{dimension})
    {
	$c->log->debug("dimension: $plot->{dimension}");
	if ($c->config->{default_units}->{$plot->{dimension}})
	{
	    $plot->{unit} = $c->config->{default_units}->{$plot->{dimension}};
	}
    }

    my $plotimg = $plot->plot;
    if (defined $plotimg)
    {
	$c->log->debug("Generated plot image: $plotimg");

	$c->res->body(IO::File->new($plotimg, 'r'));
	$c->res->content_type('image/png');
    }
    else
    {
	$c->res->body("Plot failed\n");
	$c->res->code(500);
    }
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
