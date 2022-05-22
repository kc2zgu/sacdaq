package MQTTPub;

use strict;
use utf8;

use Net::MQTT::Simple;
use JSON;

my $mqtt_client;

my %hass_classes = (TEMP => 'temperature',
                    RH => 'humidity',
                    PRES => 'pressure'
                   );

my %hass_units = (Celsius => '°C',
                  Pascal => 'Pa',
                  Percent => '%'
                  );

sub open {
    my $host = shift;

    $mqtt_client = Net::MQTT::Simple->new($host);
}

sub publish {
    my ($class, $key, $value, $data) = @_;

    $mqtt_client->retain("sacdaq/$class/$key/$value", $data);
}

sub publish_hass_discovery {
    my ($name, $topic, $report) = @_;

    my $dim_class = $report->{DIMENSION};
    $dim_class = $hass_classes{$dim_class} if exists $hass_classes{$dim_class};
    my $hass_unit = $report->{UNIT};
    $hass_unit = $hass_units{$report->{UNIT}} if exists $hass_units{$hass_unit};
    my $u = DimValue::symbol($report->{UNIT});

    my $discovery = {name => $name,
                     device_class => $dim_class,
                     state_class => 'measurement',
                     state_topic => $topic,
                     unit_of_measurement => $hass_unit,
                     unique_id => "sacdaq.$name"
                    };

    $mqtt_client->retain("homeassistant/sensor/$name/config", encode_json($discovery));
}

1;
