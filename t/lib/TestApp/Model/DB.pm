package TestApp::Model::DB;

use Moose;

BEGIN {
    extends qw/Catalyst::Model::DBIC::Schema/;
}

__PACKAGE__->config( schema_class => 'TestApp::Schema', );



1;
