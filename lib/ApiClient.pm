package ApiClient;

use strict;

use HTTP::Tiny;
use JSON;

sub new {
    my ($class, $host) = @_;

    my $self = {host => $host,
                http => HTTP::Tiny->new,
                json => JSON->new,
                apiversion => 1
               };

    #$self->{json}->pretty(1);
    $self->{json}->canonical(1);

    bless $self, $class;
}

sub _get {
    my ($self, $path, %args) = @_;

    $args{apiver} = $self->{apiversion} unless exists $args{apiver};

    my $url = $self->{host} . $path . '?' . join('&', map {"$_=$args{$_}"} sort keys %args);

    print STDERR "GET $url\n";

    return $self->{http}->get($url);
}

sub _post {
    my ($self, $path, $content, $type) = @_;

    my $url = $self->{host} . $path;

    print STDERR "POST $url $type\n";

    return $self->{http}->post($url, {content => $content, headers => {'Content-type' => $type}});
}

sub getstatus {
    my ($self, $uuid) = @_;

    my $res = $self->_get("sensorstatus/$uuid");

    print "response data: $res->{content}\n";

    return $self->{json}->decode($res->{content});
}

sub sendreports {
    my ($self, $uuid, $name, @reports) = @_;

    my @jsonreports;
    for my $report(@reports)
    {
        push @jsonreports, {time => $report->time, 
                            result => $report->result, 
                            valid => $report->valid, 
                            dimension => $report->dimension, 
                            value => $report->value, 
                            unit => $report->unit, 
                            driver => $report->driver, 
                            faults => $report->faults, 
                            extensions => $report->{extensions}};
    }

    my $res = $self->_post("sendreports/$uuid",
                           $self->{json}->encode({apiver => $self->{apiversion}, name => $name, reports => \@jsonreports}),
                           'application/json');

    return $self->{json}->decode($res->{content});
}

1;
