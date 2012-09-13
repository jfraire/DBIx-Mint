#!/usr/bin/perl

use lib 't';
use Test::DB;
use Test::More tests => 14;
use strict;
use warnings;

### Tests for insert_into

BEGIN {
    use_ok 'DBIx::Mint';
    use_ok 'DBIx::Mint::Schema';
}

{
    package Bloodbowl::Team; use Moo;
    with 'DBIx::Mint::Table';

    has id           => ( is => 'rw' );
    has name         => ( is => 'rw' );
    has coach        => ( is => 'rw' );
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
    class    => 'Bloodbowl::Team',
    table    => 'teams',
    pk       => 'id',
    auto_pk  => 1
);

$schema->add_class(
    class    => 'Bloodbowl::Player',
    table    => 'players',
    pk       => 'id',
    auto_pk  => 1
);

# This is a one-to-many relationship...
$schema->add_relationship(
    from_class     => 'Bloodbowl::Team',
    to_class       => 'Bloodbowl::Player',
    conditions     => { id => 'team'},
    method         => 'get_players',
    result_as      => 'as_iterator',
    insert_into    => 'add_players',
    inverse_method => 'get_team',
);

can_ok('Bloodbowl::Team',    'add_players' );

# Database connection
my $mint = DBIx::Mint->instance;
my $dbh  = Test::DB->init_db;
$mint->dbh($dbh);
ok( DBIx::Mint->instance->has_dbh,          'Mint has a database handle');

{
    my $team = Bloodbowl::Team->find(1);
    isa_ok($team, 'Bloodbowl::Team');
    my $iter = $team->get_players;
    isa_ok $iter, 'DBIx::Mint::ResultSet';
    
    my $count = 0;
    while (my $player = $iter->next) {
        $count++ if ref $player eq 'Bloodbowl::Player' && $player->team == 1;
    }
    is $count, 5,                           'Relationship returns an iterator that works';
}
{
    my $team = Bloodbowl::Team->find(1);
    my @ids  = $team->add_players(
        { name => 'player xyz', position => 'first'  },
        { name => 'player wxy', position => 'middle' },
        { name => 'player vwx', position => 'back'   },
    );
    is @ids, 3,                              'There are as many ids returned as records inserted';
    like $ids[0], qr{\d+},                   'Primary keys were returned by insert_into';
    
    my $player = Bloodbowl::Player->find($ids[2]);
    isa_ok $player, 'Bloodbowl::Player';
    is $player->name, 'player vwx',          'Retrieved record is correct';
    is $player->team, 1,                     'And it does point to the object that inserted it';
    my $test = $player->get_team;
    is $test->name, 'Tinieblas',             'The foreign key record was retrieved by inverse_method'; 
}

$dbh->disconnect;
done_testing();
