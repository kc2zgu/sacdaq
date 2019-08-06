package SacDaq::Web::View::Web_TT;
use Moose;
use namespace::autoclean;

extends 'Catalyst::View::TT';

__PACKAGE__->config(
    TEMPLATE_EXTENSION => '.tt',
    render_die => 1,
);

=head1 NAME

SacDaq::Web::View::Web_TT - TT View for SacDaq::Web

=head1 DESCRIPTION

TT View for SacDaq::Web.

=head1 SEE ALSO

L<SacDaq::Web>

=head1 AUTHOR

Stephen Cavilia

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
