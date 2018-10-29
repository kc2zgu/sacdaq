use utf8;
package SensDB::Result::Sensordef;

# Created by DBIx::Class::Schema::Loader
# DO NOT MODIFY THE FIRST PART OF THIS FILE

=head1 NAME

SensDB::Result::Sensordef

=cut

use strict;
use warnings;

use base 'DBIx::Class::Core';

=head1 TABLE: C<sensordef>

=cut

__PACKAGE__->table("sensordef");

=head1 ACCESSORS

=head2 localid

  data_type: 'integer'
  is_auto_increment: 1
  is_nullable: 0

=head2 name

  data_type: 'text'
  is_nullable: 0

=head2 uuid

  data_type: 'text'
  is_nullable: 0

=head2 dimension

  data_type: 'text'
  is_nullable: 1

=cut

__PACKAGE__->add_columns(
  "localid",
  { data_type => "integer", is_auto_increment => 1, is_nullable => 0 },
  "name",
  { data_type => "text", is_nullable => 0 },
  "uuid",
  { data_type => "text", is_nullable => 0 },
  "dimension",
  { data_type => "text", is_nullable => 1 },
);

=head1 PRIMARY KEY

=over 4

=item * L</localid>

=back

=cut

__PACKAGE__->set_primary_key("localid");

=head1 UNIQUE CONSTRAINTS

=head2 C<uuid_unique>

=over 4

=item * L</uuid>

=back

=cut

__PACKAGE__->add_unique_constraint("uuid_unique", ["uuid"]);

=head1 RELATIONS

=head2 reports

Type: has_many

Related object: L<SensDB::Result::Report>

=cut

__PACKAGE__->has_many(
  "reports",
  "SensDB::Result::Report",
  { "foreign.sensorid" => "self.localid" },
  { cascade_copy => 0, cascade_delete => 0 },
);


# Created by DBIx::Class::Schema::Loader v0.07049 @ 2018-10-29 15:41:52
# DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:0iApjRGKpntC8qJe4G+Rpw


# You can replace this text with custom code or comments, and it will be preserved on regeneration
1;
