use utf8;
package SensDB::Result::Report;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

SensDB::Result::Report

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<reports>

=cut

__PACKAGE__->table("reports");

=head1 ACCESSORS

=head2 sensorid

  data_type: 'integer'
  is_foreign_key: 1
  is_nullable: 0

=head2 time

  data_type: 'text'
  is_nullable: 0

=head2 result

  data_type: 'integer'
  is_nullable: 0

=head2 valid

  data_type: 'integer'
  is_nullable: 0

=head2 dimension

  data_type: 'text'
  is_nullable: 0

=head2 value

  data_type: 'numeric'
  is_nullable: 0

=head2 unit

  data_type: 'text'
  is_nullable: 1

=head2 driver

  data_type: 'text'
  is_nullable: 1

=head2 faults

  data_type: 'text'
  is_nullable: 1

=head2 extensions

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "sensorid",
  { data_type => "integer", is_foreign_key => 1, is_nullable => 0 },
  "time",
  { data_type => "text", is_nullable => 0 },
  "result",
  { data_type => "integer", is_nullable => 0 },
  "valid",
  { data_type => "integer", is_nullable => 0 },
  "dimension",
  { data_type => "text", is_nullable => 0 },
  "value",
  { data_type => "numeric", is_nullable => 0 },
  "unit",
  { data_type => "text", is_nullable => 1 },
  "driver",
  { data_type => "text", is_nullable => 1 },
  "faults",
  { data_type => "text", is_nullable => 1 },
  "extensions",
  { data_type => "text", is_nullable => 1 },
);

=head1 RELATIONS

=head2 sensorid

Type: belongs_to

Related object: L<SensDB::Result::Sensordef>

=cut

__PACKAGE__->belongs_to(
  "sensorid",
  "SensDB::Result::Sensordef",
  { localid => "sensorid" },
  { is_deferrable => 0, on_delete => "NO ACTION", on_update => "NO ACTION" },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2018-10-29 14:25:27
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:5wrAb1ibS3Tn5l0xIOZp5A


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
