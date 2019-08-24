package SacDaq::Web::Model::SensorData;
use Moose;
use namespace::autoclean;

extends 'Catalyst::Model';

=head1 NAME

SacDaq::Web::Model::SensorData - Catalyst Model

=head1 DESCRIPTION

Catalyst Model.


=encoding utf8

=head1 AUTHOR

Stephen Cavilia

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

__PACKAGE__->meta->make_immutable;

sub format_value {
    my ($self, $report) = @_;

    my $dim = $report->dimension;
    my $value = $report->value;
    my $unit = $report->unit;
    my $prec = 0.05;

    if ($dim eq 'TEMP')
    {
        my ($val_c, $val_f);
        if ($unit eq 'Celsius')
        {
            $val_c = _format_digits($value, $prec);
            $val_f = _format_digits($value * 1.8 + 32, $prec);
            return "$val_c &deg;C / $val_f &deg;F";
        }
    }
    else
    {
        return "$value $unit";
    }
}

sub _format_digits {
    my ($value, $prec) = @_;

    if (!defined($prec))
    {
        return sprintf('%.1f', $value);
    }
    elsif ($prec < 0.01)
    {
        return sprintf('%.3f', $value);
    }
    elsif ($prec < 0.09)
    {
        return sprintf('%.2f', $value);
    }
    elsif ($prec < 0.3)
    {
        return sprintf('%.1f', $value);
    }
    elsif ($prec > 0.6)
    {
        return sprintf('%d', $value);
    }
    else
    {
        return sprintf('%.1f', $value);
    }
}

1;
