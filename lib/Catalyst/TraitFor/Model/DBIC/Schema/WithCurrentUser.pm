package Catalyst::TraitFor::Model::DBIC::Schema::WithCurrentUser;

use Moose::Role;
requires 'ACCEPT_CONTEXT';

our %RE_ENTRY;

sub ACCEPT_CONTEXT {
    my $self = shift;
    return $self if $RE_ENTRY{$self};
    local $RE_ENTRY{$self} = 1;
    return $self->next::method(@_);
}

sub build_per_context_instance {
    my ( $self, $c ) = @_;
    my $new = bless {%$self}, ref $self;
    if ( $c->user_exists ) {
        $new->schema( $new->schema->clone )->current_user( $c->user );
    }
    return $new;
}

1;
