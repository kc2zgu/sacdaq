package SacDaq::Web::Controller::Sensor;
use Moose;
use namespace::autoclean;

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
    $c->stash->{reports} = \@reports;
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
