#!/usr/bin/perl

use lib 't';
use Test::DB;
use Test::More;
use strict;
use warnings;

BEGIN {
    use_ok 'DBIx::Mint';
}

my $dbh;
$dbh = DBIx::Mint->instance->connect( Test::DB::connection_params() );
isa_ok($dbh, 'DBI::db');
isa_ok(DBIx::Mint->instance->connector, 'DBIx::Connector');

my $dbh2 = DBIx::Mint->instance->dbh;
isa_ok($dbh2, 'DBI::db');



done_testing();
