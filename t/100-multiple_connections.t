#!/usr/bin/perl

use lib 't';
use Test::More;
use strict;
use warnings;

# Tests for DBIx::Mint::Table -- Multiple conections

BEGIN {
    use_ok 'DBIx::Mint';
    use_ok 'Test::DB';
    use_ok 'Test::DB2';
}

# Connect to the first database
Test::DB->connect_db;
my $mint = DBIx::Mint->instance;
isa_ok( $mint, 'DBIx::Mint');

my $schema = $mint->schema;
isa_ok( $schema, 'DBIx::Mint::Schema');

$schema->add_class(
    class    => 'Bloodbowl::Coach',
    table    => 'coaches',
    pk       => 'id',
    auto_pk  => 1
);
$schema->add_class(
    class    => 'Bloodbowl::Skill',
    table    => 'skills',
    pk       => 'name',
);


# Connect to the second database
Test::DB2->connect_db();
my $mint2 = DBIx::Mint->instance('BB2');
isa_ok( $mint2, 'DBIx::Mint');

my $schema2 = $mint2->schema;
isa_ok( $schema2, 'DBIx::Mint::Schema');

$schema2->add_class(
    class    => 'Bloodbowl::Coach',
    table    => 'coaches',
    pk       => 'id',
    auto_pk  => 1
);
$schema2->add_class(
    class    => 'Bloodbowl::Skill',
    table    => 'skills',
    pk       => 'name',
);

# Test ResultSet objects
my $rs1 = DBIx::Mint::ResultSet->new( table => 'coaches' );
isa_ok $rs1, 'DBIx::Mint::ResultSet';

my $rs2 = DBIx::Mint::ResultSet->new( table => 'coaches', instance => 'BB2' );
isa_ok $rs2, 'DBIx::Mint::ResultSet';

my $coach_1 = $rs1->search({ name => 'user_a'})->single;
is $coach_1->{password}, 'wwww', 'User fetched correctly from default database';

my $coach_2 = $rs2->search({ name => 'bb2_a'})->single;
is $coach_2->{password}, 'aaaa', 'User fetched correctly from second database';



done_testing();
