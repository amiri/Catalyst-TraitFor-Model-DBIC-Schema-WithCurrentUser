package Catalyst::TraitFor::Model::DBIC::Schema::WithCurrentUser;

use Moose::Role;
requires 'ACCEPT_CONTEXT';
with 'Catalyst::Component::InstancePerContext';

# ABSTRACT: Puts the context's current user into your Catalyst::Model::DBIC::Schema schema.

our %RE_ENTRY;

sub ACCEPT_CONTEXT {
    my $self = shift;
    return $self if $RE_ENTRY{$self};
    local $RE_ENTRY{$self} = 1;
    return $self->build_per_context_instance(@_);
}

sub build_per_context_instance {
    my ( $self, $ctx ) = @_;
    my $new = bless {%$self}, ref $self;
    if ( $ctx->user_exists ) {
        $new->schema( $new->schema->clone )->current_user( $ctx->user );
    }
    return $new;
}

1;

=head1 NAME

Catalyst::TraitFor::Model::DBIC::Schema::WithCurrentUser

=head1 SYNOPSIS

    package MyApp::Model::DB;

    use Moose;
    extends qw/Catalyst::Model::DBIC::Schema/;
    with 'Catalyst::TraitFor::Model::DBIC::Schema::WithCurrentUser'; # This is the
                                                                     # important bit.

    __PACKAGE__->config(
        {   schema_class => 'MyApp::Schema',
            connect_info => { dsn => 'dbi:SQLite:dbname=:memory:' },
        }
    );

    1;

    ...

    package MyApp::Schema;

    use Moose;
    extends qw/DBIx::Class::Schema/;

    has 'current_user' => ( is => 'rw', ); # This is all you have to add to
                                           # the schema

    __PACKAGE__->load_namespaces;

    1;


=head1 DESCRIPTION

This is a trait for a Catalyst::Model::DBIC::Schema object. All you need to do
is add a current_user to your schema, and then use the role in your Model::DB.

This module makes it easy to have a "pre-authorized" schema and resultsets
by using L<DBIx::Class::Schema::RestrictWithObject>. Here's a real example:

    package MyApp::Schema;

    use Moose;
    use List::MoreUtils qw/any/;
    extends 'DBIx::Class::Schema';

    has current_user => ( is => 'rw' );

    __PACKAGE__->load_components(qw/Schema::RestrictWithObject/);
    __PACKAGE__->load_namespaces;

    around resultset => sub {
      my ( $orig, $self ) = ( shift, shift );
      my $new_rs = $self->$orig(@_);
      if ( any { $new_rs->result_source->source_name eq $_ }
        qw/Blog Comment Message/ )
      {
        my $schema =
          $self->restrict_with_object(
          $self->resultset('Restrictions')->first ); # This is a resultset
                                                     # that has methods for
                                                     # restricting everything
                                                     # in @resultsets_to_restrict;
                                                     # see below
        my $restrictor =
          "restrict_${\$new_rs->result_source->source_name}_resultset"; # This
                                                                        # is the
                                                                        # method
                                                                        # we will call
                                                                        # in our
                                                                        # Restrictions
                                                                        # resultset.
        if ( $schema->restricting_object
          && $schema->restricting_object->can($restrictor) )
        {
          $new_rs = $schema->restricting_object->$restrictor($new_rs);
        }
      }                                             # So, here we restrict the
                                                    # schema with a resultset
                                                    # returned from our restrictor
                                                    # generator.
      return $new_rs;
    };

    1;

Here is an example of what can go on in MyApp::Schema::Result::Restriction:

    package MyApp::Schema::Result::Restriction;

    use Moose;
    use List::MoreUtils qw/any/;
    use Method::Signatures::Simple;
    extends 'DBIx::Class::Core';

    __PACKAGE__->table("restriction");
    __PACKAGE__->add_columns(
      "approved",
      ...
      "approved_by",
      ...
      "approved_at",
      ...
      "item",
      ...
    );
    __PACKAGE__->set_primary_key("item");

    __PACKAGE__->might_have(
      "blog",
      ...
    );
    __PACKAGE__->might_have(
      "comment",
      ...
    );
    __PACKAGE__->might_have(
      "message",
      ...
    );

    method restrict_Blog_resultset($rs) {
      return $self->restriction( "blog", $rs );
    }

    method restrict_Comment_resultset($rs) {
      return $self->restriction( "comment", $rs );
    }

    method restrict_Message_resultset($rs) {
      return $self->restriction( "message", $rs );
    }


    method restriction( $table, $rs ) {
      return $self->result_source->schema
        ->resultset('Restriction')
        ->related_resultset($table)
        unless $self->result_source->schema->current_user;  # Return a restricted
                                                            # rs if no user.
      return $rs
        if any { $_ =~ /admin/ }
        $self->result_source->schema->current_user->roles;  # Return an unrestricted
                                                            # rs if user is an admin
      return $self->result_source->schema
        ->resultset('Restriction')
        ->related_resultset($table);                        # Return a restricted
                                                            # rs if user is not an
                                                            # admin.
    }

    1;

That's about it!


=head1 AUTHOR

Amiri Barksdale E<lt>amiri@arisdottle.netE<gt>

=head1 SEE ALSO

L<DBIx::Class::Schema::RestrictWithObject>, L<DBIx::Class>, L<Catalyst::Model::DBIC::Schema>

=head1 LICENSE

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself.

=cut
