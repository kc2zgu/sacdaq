package MQTTPub;

use strict;

use Net::MQTT::Simple;

my $mqtt_client;

sub open {
    my $host = shift;

    $mqtt_client = Net::MQTT::Simple->new($host);
}

sub publish {
    my ($class, $key, $value, $data) = @_;

    $mqtt_client->retain("sacdaq/$class/$key/$value", $data);
}

1;
