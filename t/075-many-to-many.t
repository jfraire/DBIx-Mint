#!/usr/bin/perl

use lib 't';
use Test::DB;
use Test::More tests;
use strict;
use warnings;

### Tests for many_to_many

BEGIN {
    use_ok 'DBIx::Mint';
    use_ok 'DBIx::Mint::Schema';
    use_ok 'DBIx::Mint::ResultSet';
}

{
    package Bloodbowl::Skill; use Moo;
    with 'DBIx::Mint::Table';

    has name         => ( is => 'rw' );
    has category     => ( is => 'rw' );
}
{
    package Bloodbowl::Player; use Moo;
    with 'DBIx::Mint::Table';

    has id           => ( is => 'rw' );
    has name         => ( is => 'rw' );
    has position     => ( is => 'rw' );
    has team         => ( is => 'rw' );
}

my $schema = DBIx::Mint::Schema->instance;
isa_ok( $schema, 'DBIx::Mint::Schema');

$schema->add_class(
    class    => 'Bloodbowl::Skill',
    table    => 'skills',
    pk       => 'id',
    auto_pk  => 1
);

$schema->add_class(
    class    => 'Bloodbowl::Player',
    table    => 'players',
    pk       => 'id',
    auto_pk  => 1
);

# This is a many-to-many relationship...
$schema->many_to_many(
    conditions     => [ 'Bloodbowl::Player',       { id => 'player'}, 
                        'Bloodbowl::PlayerSkills', { skill => 'name'}, 
                        'Bloodbowl::Skill' ],
    method         => 'get_skills',
    inverse_method => 'get_players',
);
can_ok('Bloodbowl::Team',                   'add_players' );

# Database connection
my $mint = DBIx::Mint->instance;
my $dbh  = Test::DB->init_db;
$mint->dbh($dbh);
ok( DBIx::Mint->instance->has_dbh,          'Mint has a database handle');
    
{
    my $player = Bloodbowl::Player->find(1);
    my @skills = $player->get_skills;
    is @skills, 2,                          'Retrieved all records from a many-to-many relationship';
    isa_ok $skills[0], 'Bloodbowl::Skill';
}
{
    my $skill   = Bloodbowl::Player->find('skill b');
    my @players = $skill->get_players;
    is @players, 1,                         'Retrieved all records following the relationship backwards';
    isa_ok $players[0], 'Bloodbowl::Player';
    is $players[0]->name, 'player1',        'Retrieved record is correct';
}

$dbh->disconnect;
done_testing();
