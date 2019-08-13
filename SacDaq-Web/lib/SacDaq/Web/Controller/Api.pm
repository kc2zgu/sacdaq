package SacDaq::Web::Controller::Api;
use Moose;
use namespace::autoclean;
use JSON;
use File::Slurp;
use UUID::Tiny;

BEGIN { extends 'Catalyst::Controller'; }

=head1 NAME

SacDaq::Web::Controller::Api - Catalyst Controller

=head1 DESCRIPTION

Catalyst Controller.

=head1 METHODS

=cut


=head2 index

=cut

my $defaultver = 1;
my $maxsync = 500;

sub index :Path :Args(0) {
    my ( $self, $c ) = @_;

    $c->response->body('Matched SacDaq::Web::Controller::Api in Api.');
}

sub init :PathPart('api') :Chained('/') :CaptureArgs(0) {
    my ($self, $c) = @_;

    if ($c->req->method eq 'GET')
    {
        $c->log->debug('API GET request');
        my $reqver;
        if ($c->req->param('apiver'))
        {
            $reqver = $c->req->param('apiver');
            $c->log->debug("Request version $reqver");
        }
        else
        {
            $c->log->debug("No version in request, defaulting to $defaultver");
            $reqver = $defaultver;
        }
        $c->stash->{reqver} = $reqver;
    }
    elsif ($c->req->method eq 'POST')
    {
        my $type = $c->req->content_type;
        $c->log->debug("API POST request type $type");
        if ($type =~ /^application\/json/)
        {
            my $body = read_file($c->req->body);
            $c->log->debug("JSON data: $body");
            $c->stash->{req_data} = JSON::decode_json($body);
            my $reqver;
            if ($c->stash->{req_data}->{apiver})
            {
                $reqver = $c->stash->{req_data}->{apiver};
                $c->log->debug("Request version $reqver");
            }
            else
	    {
                $c->log->debug("No version in request, defaulting to $defaultver");
                $reqver = $defaultver;
            }
            $c->stash->{reqver} = $reqver;
        }
    }
    else
    {
        my $method = $c->req->method;
        $c->log->debug("method $method not allowed");
    }
    $c->stash->{current_view} = 'JSON';
}

sub sensorstatus :Chained('init') :Args(1) {
    my ($self, $c) = @_;

    my $uuid = $c->req->args->[0];

    $c->log->debug("sensorstatus API req: uuid=$uuid");

    if (UUID::Tiny::is_uuid_string($uuid))
    {
        $c->stash->{response}->{uuid} = $uuid;
        $c->stash->{response}->{sync_limit} = $maxsync;
        my $db = $c->model('SensDB');
        my $sensordef = $db->resultset('Sensordef')->find({uuid => $uuid});
        if (defined $sensordef)
	{
            $c->stash->{response}->{exists} = 1;
            $c->stash->{response}->{sensorname} = $sensordef->name;
            my $rec_count = $sensordef->search_related('reports')->count;
            $c->stash->{repsonse}->{reports} = $rec_count;
            if ($rec_count > 0)
            {
                my ($lastrep) = $sensordef->search_related('reports', {},
                                                           {order_by => {-desc=>'time'},
                                                            rows => 1});
                $c->stash->{response}->{last_datetime} = $lastrep->time . "";
            }
        }
        else
        {
            $c->stash->{response}->{exists} = 0;
        }
        $c->stash->{response}->{status} = 'success';
    }
    else
    {
        $c->stash->{response}->{status} = 'fail';
        $c->stash->{response}->{error} = 'baduuid';
    }

    $c->forward('View::JSON');
}

sub sendreports :Chained('init') :Args(1) {
    my ($self, $c) = @_;

    my $uuid = $c->req->args->[0];

    my @reports = @{$c->stash->{req_data}->{reports}};
    my $repcount = @reports;
    $c->log->debug("Received $repcount reports for $uuid");

    my $db = $c->model('SensDB');
    my $sensordef = $db->resultset('Sensordef')->find({uuid => $uuid});
    unless (defined $sensordef)
    {
        $c->log->debug("Creating new sensor definition");
        my $name = $c->stash->{req_data}->{name};
        my $dim = $reports[0]->{dimension};
        $c->log->debug("$uuid $name $dim");

        $sensordef = $db->resultset('Sensordef')->create({uuid => $uuid,
                                                          name => $name,
                                                          dimension => $dim});
    }

    my $inserted = 0;
    for my $rep(@reports)
    {
        my $keys = {time => $rep->{time},
                    result => $rep->{result},
                    valid => $rep->{valid},
                    dimension => $rep->{dimension},
                    value => $rep->{value},
                    unit => $rep->{unit},
                    driver => $rep->{driver},
                    faults => $rep->{faults},
                    extensions => $rep->{extensions}};
        my $newreport = $sensordef->create_related(reports => $keys);
        $inserted++;
    }

    $c->stash->{response}->{status} = 'success';
    $c->stash->{response}->{inserted} = $inserted;

    $c->forward('View::JSON');
}


=encoding utf8

=head1 AUTHOR

Stephen Cavilia

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

1;
