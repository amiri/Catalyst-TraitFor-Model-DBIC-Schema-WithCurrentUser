package TestApp::Schema;

use Moose;
extends qw/DBIx::Class::Schema/;

__PACKAGE__->load_namespaces;

1;
