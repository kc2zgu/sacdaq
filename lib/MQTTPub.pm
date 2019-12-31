package MQTTPub;

use strict;

use Net::MQTT::Simple;

my $mqtt_client;

sub open {
    my $host = shift;

    $mqtt_client = Net::MQTT::Simple->new($host);
}

sub publish {
    my ($sensor, $value) = @_;

    $mqtt_client->retain("sacdaq/sensor/$sensor", $value);
}

1;
