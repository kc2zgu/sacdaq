package SacDaq::Web::Controller::Root;
use Moose;
use namespace::autoclean;

BEGIN { extends 'Catalyst::Controller' }

#
# Sets the actions in this controller to be registered with no prefix
# so they function identically to actions created in MyApp.pm
#
__PACKAGE__->config(namespace => '');

=encoding utf-8

=head1 NAME

SacDaq::Web::Controller::Root - Root Controller for SacDaq::Web

=head1 DESCRIPTION

[enter your description here]

=head1 METHODS

=head2 index

The root page (/)

=cut

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    my $db = $c->model('SensDB');
    my $sd = $c->model('SensorData');
    my @sensors = $db->resultset('Sensordef')->all();
    my @sensordata;

    for my $sensor(@sensors)
    {
        my $uuid = $sensor->uuid;
        my $data = {name => $sensor->name, uuid => $uuid};
        my $rec_count = $sensor->search_related('reports')->count;
        $data->{reports} = $rec_count;
        if ($rec_count > 0)
        {
            my ($lastrep) = $sensor->search_related('reports', {},
                                                    {order_by => {-desc=>'time'},
                                                     rows => 1});
            $data->{last_datetime} = $lastrep->time;
	    my $dv = $lastrep->dimvalue;
	    my $dvf = $dv->format();
	    if ($c->config->{default_units}->{$lastrep->dimension})
	    {
		eval {
		    $dvf = $dv->convert_format($c->config->{default_units}->{$lastrep->dimension});
		};
	    }
            $data->{last_value} = $dvf;
        }
        push @sensordata, $data;
    }

    $c->stash->{sensors} = [sort {$b->{last_datetime} <=> $a->{last_datetime}} @sensordata];

    $c->forward('View::Web_TT');
}

=head2 default

Standard 404 error page

=cut

sub default :Path {
    my ( $self, $c ) = @_;
    $c->response->body( 'Page not found' );
    $c->response->status(404);
}

=head2 end

Attempt to render a view, if needed.

=cut

sub end : ActionClass('RenderView') {}

sub begin :Private {
    my ($self, $c) = @_;

    my $tz = DateTime::TimeZone->new(name => $c->config->{timezone});
    $c->stash->{tz} = $tz;
    $c->stash->{local_time} = sub {my $dt = $_[0]->clone;
				   $dt->set_time_zone('UTC');
				   $dt->set_time_zone($tz);
				   $dt->strftime("%F %H:%M")};
    $c->stash->{local_time_iso} = sub {my $dt = $_[0]->clone;
				       $dt->set_time_zone('UTC');
				       $dt->set_time_zone($tz);
				       $dt->strftime("%FT%H:%M:%S")};    
}

=head1 AUTHOR

Stephen Cavilia

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
