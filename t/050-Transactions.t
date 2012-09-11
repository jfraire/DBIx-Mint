#!/usr/bin/perl

use lib 't';
use Test::DB;
use Test::More tests => 8;
use Test::Warn;
use strict;
use warnings;

# Tests for transactions

BEGIN {
    use_ok 'DBIx::Mint';
}

{
    package Bloodbowl::Coach; use Moo;
    with 'DBIx::Mint::Table';
    
    has id           => ( is => 'rw', predicate => 1 );
    has name         => ( is => 'rw' );
    has email        => ( is => 'rw' );
    has password     => ( is => 'rw' );
}

my $mint   = DBIx::Mint->instance;
my $schema = $mint->schema;
isa_ok( $mint,   'DBIx::Mint');
isa_ok( $schema, 'DBIx::Mint::Schema');

$schema->add_class(
    class    => 'Bloodbowl::Coach',
    table    => 'coaches',
    pk       => 'id',
    auto_pk  => 1
);

my $dbh = Test::DB->init_db;
$mint->dbh($dbh);

my $transaction = sub {
    # This is the transaction
    my $coach = Bloodbowl::Coach->find(1);
    $coach->name('user x');
    $coach->update;
    
    my $test = Bloodbowl::Coach->find(1);
    is($test->name, 'user x',  'Record updated within transaction');
    
    die "Abort transaction";
};

my $res;
warning_is
    { $res = $mint->do_transaction( $transaction ) }
    "Transaction failed: Abort transaction",
    'Failed transactions emit a warning'
;
is $res, undef, 'Failed transactions return undef';

my $coach = Bloodbowl::Coach->find(1);
isnt $coach->name, 'user x',   'Failed transactions are rolled back successfuly';
is   $coach->name, 'julio_f',  'Record was not changed by a rolled back transaction';

$dbh->disconnect;
done_testing();
