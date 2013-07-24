#!/usr/bin/perl

use lib 't';
use Test::More;
use strict;
use warnings;

# Tests for DBIx::Mint::Table with a connection other than default

BEGIN {
    use_ok 'DBIx::Mint';
    use_ok 'Test::DB2';
    use_ok 'Bloodbowl::Coach';
}

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

# Create
my @to_verify;
{
    # This test exercises both create and insert with a named connection
    my $coach = Bloodbowl::Coach->create( $mint2,
        { name => 'testing', email => 'testing@coaches.net', password => 'weak' });
    isa_ok $coach, 'Bloodbowl::Coach';
    like $coach->id, qr/^\d+$/, 'Created object has expected auto-generated primary key';
    push @to_verify, $coach->id;
}
{
    # Excercise find, result_set and update. Update uses the instance variant
    my $coach = Bloodbowl::Coach->find( $mint2, $to_verify[0] );
    isa_ok $coach, 'Bloodbowl::Coach';
    is $coach->name, 'testing', 'Object retrieved correctly using named Mint object';
    $coach->name('updated');
    $coach->update;

    my $rs = Bloodbowl::Coach->result_set( $mint2 )
        ->search({ name => 'updated' })
        ->set_target_class('Bloodbowl::Coach');
    my $found = $rs->single;
    is $found->id, $coach->id, 'Update used as instance method works';
}


done_testing();
