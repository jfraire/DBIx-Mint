#!/usr/bin/perl

use lib 't';
use Test::DB;
use Test::More;
use strict;
use warnings;

# Tests for DBIx::Mint::Table

BEGIN {
    use_ok 'DBIx::Mint';
    use_ok 'DBIx::Mint::Table';
    use_ok 'DBIx::Mint::Schema';
}

my $dbh  = Test::DB->init_db;
my $mint = DBIx::Mint->instance( dbh => $dbh );
isa_ok( $mint, 'DBIx::Mint');

my $schema = DBIx::Mint::Schema->instance;
$schema->add_class(
    class    => 'Bloodbowl::Coach',
    table    => 'coaches',
    pk       => 'id',
    auto_pk  => 1
);
isa_ok( $schema, 'DBIx::Mint::Schema');

{
    package Bloodbowl::Coach;
    use Moo;
    with 'DBIx::Mint::Table';
    
    has id           => ( is => 'rw', predicate => 1 );
    has name         => ( is => 'rw' );
    has email        => ( is => 'rw' );
    has password     => ( is => 'rw' );
}


# Tests for Find
{
    my $user = Bloodbowl::Coach->find({ name => 'user_a' });
    isa_ok($user, 'Bloodbowl::Coach');
    is($user->{id},    2,                   'Record fetched correctly by find, with where clause');
}
{
    my $user = Bloodbowl::Coach->find(3);
    isa_ok($user, 'Bloodbowl::Coach');
    is($user->{id},    3,                   'Record fetched correctly by find');
}
{
    my $user = Bloodbowl::Coach->find('a');
    ok !defined $user,                      'Retreiving a non-existent record returns undef';
}

# Tests for insert
{
    my $user  = Bloodbowl::Coach->new(name => 'user d', email => 'd@blah.com', password => 'xxx');
    my @ids   = Bloodbowl::Coach->insert(
        $user,
        {name => 'user e', email => 'e@blah.com', password => 'xxx'}, 
        {name => 'user f', email => 'f@blah.com', password => 'xxx'}, 
    );
    ok defined $user->id,  'Inserted object has the auto-generated id field';
    is $user->id, $ids[0], 'Auto-generated id field is the same as the one returned';
}
{
    my $user  = Bloodbowl::Coach->new(name => 'user h', email => 'h@blah.com', password => 'xxx');
    my $id    = $user->insert;
    ok defined $user->id,  'Inserted object has the auto-generated id field';
    is $user->id, $id,     'Auto-generated id field is the same as the one returned';
}
{
    my $id   = Bloodbowl::Coach->insert(name => 'user g', email => 'g@blah.com', password => 'xxxx');
    my $user = Bloodbowl::Coach->find($id);
    is $user->name, 'user g', 'Inserted and then retrieved user correctly'; 
}

# Tests for create
{
    my $user = Bloodbowl::Coach->create(name => 'user i', email => 'i@blah.com', password => 'xxxx');
    is $user->name, 'user i', 'Created a user correctly';
    my $tst  = Bloodbowl::Coach->find($user->id);
    is $tst->name, 'user i',  'User just created was retrieved from database correctly';
}    

# Tests for find or create
{
    my $user = Bloodbowl::Coach->find_or_create(2);
    is $user->name, 'user_a', 'Found existing user with find_or_create';
    my $test = Bloodbowl::Coach->find_or_create( name => 'user j', email => 'j@blah.com', password => 'xxx');
    ok $test->has_id,         'Created an object with find_or_create';
    $user    = Bloodbowl::Coach->find( $test->id );
    is $user->name, 'user j', 'Retrieved user created with find_or_create';
}

# Tests for update
{
    Bloodbowl::Coach->update({password => '222'});
    my $user = Bloodbowl::Coach->find(2);
    is $user->password, '222', 'Update works fine as a class method';
}
{
    my $user = Bloodbowl::Coach->find(2);
    $user->password('678');
    $user->update;
    my $test = Bloodbowl::Coach->find(2);
    is $test->password, 678,  'Update works fine as an instance method';
    $test    = Bloodbowl::Coach->find(3);
    is $test->password, 222,  'As an instance method, not all records were modified';
}

# Tests for delete
{
    Bloodbowl::Coach->delete({password => 678});
    my $user = Bloodbowl::Coach->find(2);
    ok !defined $user,   'Delete at class level works';
    $user    = Bloodbowl::Coach->find(4);
    is $user->id, 4,     'And not all the records where deleted';
    $user->delete;
    is_deeply $user, {}, 'Delete at the object level undefs the deleted object';
    my $test = Bloodbowl::Coach->find(4);
    ok !defined $test,   'Deleted object could not be found';
}

$dbh->disconnect;
done_testing();

