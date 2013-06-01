package DBIx::Mint;

use DBIx::Connector;
use DBIx::Mint::Schema;
use SQL::Abstract::More;
use Carp;
use Moo;
with 'MooX::Singleton';

our $VERSION = 0.01;

has abstract  => ( is => 'rw', default => sub { SQL::Abstract::More->new(); } );
has dbh       => ( is => 'rw', predicate => 1 );
has connector => ( is => 'rw', predicate => 1 );

sub new {
    croak "You should call DBIx::Mint->instance instead of new";
}

around dbh => sub {
    my ($orig, $self, $dbh) = @_;
    $orig->($self, $dbh) if defined $dbh;
    return $self->has_dbh       ? $orig->($self)
        :  $self->has_connector ? $self->connector->dbh
        : croak 'Please feed DBIx::Mint with a database connection';
};

sub connect {
    my $class = shift;
    my $self  = $class->instance;        
    $self->connector( DBIx::Connector->new(@_) );
    $self->connector->mode('ping');
    $self->dbh->{HandleError} = sub { croak $_[0] };
    return $self;
}

sub do_transaction {
    my ($self, $trans) = @_;
    $self->dbh->begin_work if $self->dbh->{AutoCommit};
    eval {
        &$trans;
        $self->dbh->commit;
    };
    if ($@) {
        carp "Transaction failed: $@\n";
        $self->dbh->rollback;
        return undef;
    }
    return 1;
}

sub schema {
    return DBIx::Mint::Schema->instance;
}

1;

=pod

=head1 NAME

DBIx::Mint - Yet another light-weight ORM

=head1 VERSION

This documentation refers to DBIx::Mint 0.01

=head1 SYNOPSIS

Define your classes, which will play the role L<DBIx::Mint::Table>:

 package Bloodbowl::Team;
 use Moo;
 with 'DBIx::Mint::Table';
 
 has id   => (is => 'rw' );
 has name => (is => 'rw' );
 ...

Nearby (probably in a module of its own), you define the schema for your classes:

 package Bloodbowl::Schema;

 my $schema = DBIx::Mint->instance->schema;
 $schema->add_class(
     class      => 'Bloodbowl::Team',
     table      => 'teams',
     pk         => 'id',
     auto_pk => 1,
 );
 
 $schema->add_class(
     class      => 'Bloodbowl::Player',
     table      => 'players',
     pk         => 'id',
     auto_pk => 1,
 );
 
 # This is a one-to-many relationship
 $schema->one_to_many(
     conditions     => 
        ['Bloodbowl::Team', { id => 'team'}, 'Bloodbowl::Player'],
     method         => 'get_players',
     inverse_method => 'get_team',
 );

And in your your scripts:
 
 use DBIx::Mint;
 use My::Schema;
 use DBI;
 
 # Connect to the database
 my $dbh  = DBI->connect(...);
 my $mint = DBIx::Mint->instance( dbh => $dbh );
 
 my $team    = Bloodbowl::Team->find(1);
 my @players = $team->get_players;
 
 # Database modification methods include insert, update, and delete.
 # They act on a single object when called as instance methods
 # but over the whole table if called as class methods:
 $team->name('Los Invencibles');
 $team->update;
 
 Bloodbowl::Coach->update(
    { status => 'suspended' }, 
    { password => 'blocked' });
 
To define a schema and to learn about data modification methods, look into L<DBIx::Mint::Schema> and L<DBIx::Mint::Table>.

Without a schema you can only fetch data. No data modification methods are offered. ResultSet objects build database queries and fetch the resulting records:
  
 my $rs = DBIx::Mint::ResultSet->new( table => 'coaches' );
 
 # You can perform joins:
 my @team_players = $rs->search( { 'me.id' => 1 } )
   ->inner_join( 'teams',   { 'me.id'    => 'coach' })
   ->inner_join( 'players', { 'teams.id' => 'team'  })
   ->all;

See the docs for L<DBIx::Mint::ResultSet> for all the methods you can use to retrieve data. Internally, class relationships are declared in terms of ResultSet objects.
 
=head1 DESCRIPTION

DBIx::Mint is yet another object-relational mapping module for Perl. Its goals are:

=over

=item * To be simple to understand and use

=item * To provide flexible, chaineable methods to fetch data from a database

=item * To provide a flexible, powerful way to build relationships between classes

=item * To play nice with your own classes. In particular, DBIx::Mint is build using Moo and it does not clash with accessors defined in your classes by Moo (although we do treat your objects as hash references under the hood)

=item * To be light on dependencies

=back

On the other side of the equation, it has some strong restrictions:

=over

=item * It supports a single database handle

=item * While it uses roles (through Role::Tiny/Moo::Role), it does put a lot of methods on your namespace. See L<DBIx::Mint::Table> for the list. L<DBIx::Mint::ResultSet> does not mess with your namespace at all.

=item * It expects you to create the database connection and it makes no effort to keep it alive for long-running processes.

=back

There are many ORMs for Perl. Most notably, you should look at L<DBIx::Class> and L<DBIx::DataModel>. L<DBIx::Lite> is a light-weight alternative to those two, roboust and proven ORMs.

This module is in its infancy and it is very likely to change and (gasp) risk is high that it will go unmaintained.

=head1 DOCUMENTATION

The documentation is split into four parts:

=over

=item * This general view, which documents the umbrella class DBIx::Mint. This class defines a singleton that simply holds the L<SQL::Abstract::More> object and the database handle and implements transactions. 

=item * L<DBIx::Mint::Schema> documents relationships and the mapping between classes and database tables. Learn how to specify table names, primary keys and how to create associations between classes.

=item * L<DBIx::Mint::Table> is a role that implements methods that modify or fetch data from a single table.

=item * L<DBIx::Mint::ResultSet> builds database queries using chainable methods. It does not know about the schema, so it can be used without one. Internally, associations are implemented using ResultSet objects.

=back

=head1 SUBROUTINES/METHODS IMPLEMENTED BY DBIx::Mint

This module offers a just a few starting methods:

=head2 instance

Returns an instance of DBIx::Mint. It is a singleton, so you can access it from anywhere. To make it useful you should give it a database handle.

=head2 dbh

This is the accessor/mutator for the database handle. To give DBIx::Mint a database connection, do:

 # Connect to the database
 my $dbh  = DBI->connect(...);
 my $mint = DBIx::Mint->instance( dbh => $dbh );
 
or:

 $mint->dbh( $dbh );
 
=head2 abstract

This is the accessor/mutator for the L<SQL::Abstract::More> subjacent object. You can choose to build your own object with the parameters you need and then simply stuff it into your DBIx::Mint instance:

 my $sql = SQL::Abstract::More->new(...);
 $mint->abstract($sql);
 
You can also use the default object, which is created with the defaults of SQL::Abstract::More.

=head2 schema

This is simply a method that will return your L<DBIx::Mint::Schema> instance:

 my $schema = $mint->schema;

=head2 do_transaction

This method will take a code reference and execute it within a transaction block. In case the transaction fails (your code dies) it is rolled back and B<a warning is thrown>. In this case, L<do_transaction> will return C<undef>. If successful, the transaction will be commited and the method will return a true value. 

 $mint->do_transaction( $code_ref ) || die "Transaction failed!";

=head1 DEPENDENCIES

This distribution depends on the following external, non-core modules:

=over

=item Moo

=item MooX::Singleton

=item SQL::Abstract::More

=item DBI

=item List::MoreUtils

=item Clone

=back

=head1 BUGS AND LIMITATIONS

There are no known bugs in this module (as it is too young). Testing is not complete; in particular, tests look mostly for the expected results and not for edge cases or plain incorrect input. 

Please report problems to the author. Patches are welcome. Tests are welcome also.

=head1 ACKNOWLEDGEMENTS

This module is heavily based on L<DBIx::Lite>, by Alessandro Ranellucci. The benefits of that module over DBIx::Mint are that it does provide accessors if you choose to bless your result objects and it does allow for record modifications without using a schema. The main benefits of this module over DBIx::Lite is that target classes can be based on Moo or have their own accessors defined elsewhere, which avoids clashing. Relationships are more flexible, and you are allowed to have more than one relationship between two tables.

=head1 AUTHOR

Julio Fraire, <julio.fraire@gmail.com>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2012, Julio Fraire. All rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
