package DBIx::Mint;

use DBIx::Connector;
use DBIx::Mint::Schema;
use SQL::Abstract::More;
use Carp;
use Moo;

our $VERSION = 0.04;

my %object_pool;

has name      => ( is => 'ro', default   => sub { '_DEFAULT' } );
has abstract  => ( is => 'rw', default   => sub { SQL::Abstract::More->new(); } );
has schema    => ( is => 'rw', default   => sub { return DBIx::Mint::Schema->new } );
has connector => ( is => 'rw', predicate => 1 );

sub BUILD {
    my $self = shift;
    my $name = $self->name;
    croak "DBIx::Mint object $name exists already"
        if exists $object_pool{ $name };
    $object_pool{ $name } = $self;
}

sub instance {
    my ($class, $name) = @_;
    $name //= '_DEFAULT';
    if (!exists $object_pool{$name}) {
        $class->new( name => $name );
    }
    return $object_pool{$name};
}

sub dbh {
    my $self = shift;
    return  $self->has_connector ? $self->connector->dbh
        : croak 'Please feed DBIx::Mint with a database connection';
};

sub connect {
    my $self;
    if (ref $_[0]) {
        $self = shift;
    }
    else {
        my $class = shift;
        $self = $class->instance();
    }
    $self->connector( DBIx::Connector->new(@_) );
    $self->connector->mode('ping');
    $self->dbh->{HandleError} = sub { croak $_[0] };

    return $self;
}

sub do_transaction {
    my ($self, $trans) = @_;

    my $auto = $self->dbh->{AutoCommit};
    $self->dbh->{AutoCommit} = 0 if $auto;

    my @output;    
    eval { @output = $self->connector->txn( $trans ) };

    if ($@) {
        carp "Transaction failed: $@";
        $self->dbh->rollback;
        $self->dbh->{AutoCommit} = 1 if $auto;
        return undef;
    }
    $self->dbh->{AutoCommit} = 1 if $auto;
    return @output ? @output : 1;    
}

1;

=pod

=head1 NAME

DBIx::Mint - A mostly class-based ORM for Perl

=head1 VERSION

This documentation refers to DBIx::Mint 0.04

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
     auto_pk    => 1,
 );
 
 $schema->add_class(
     class      => 'Bloodbowl::Player',
     table      => 'players',
     pk         => 'id',
     auto_pk    => 1,
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
 
 # Connect to the database
 DBIx::Mint->connect( $dsn, $user, $passwd, { dbi => 'options'} );
 
 my $team    = Bloodbowl::Team->find(1);
 my @players = $team->get_players;
 
 # Database modification methods include insert, update, and delete.
 # They act on a single object when called as instance methods
 # but over the whole table if called as class methods:
 $team->name('Los Invencibles');
 $team->update;
 
 Bloodbowl::Coach->update(
    { status   => 'suspended' }, 
    { password => 'blocked' });
 
To define a schema and to learn about data modification methods, look into L<DBIx::Mint::Schema> and L<DBIx::Mint::Table>. Declaring the schema allows you to modify the data.

If you only need to query the database, no schema is needed. ResultSet objects build database queries and fetch the resulting records:
  
 my $rs = DBIx::Mint::ResultSet->new( table => 'coaches' );
 
 # You can perform joins:
 my @team_players = $rs->search( { 'me.id' => 1 } )
   ->inner_join( 'teams',   { 'me.id'    => 'coach' })
   ->inner_join( 'players', { 'teams.id' => 'team'  })
   ->all;

See the docs for L<DBIx::Mint::ResultSet> for all the methods you can use to retrieve data. 
 
=head1 DESCRIPTION

DBIx::Mint is a mostly class-based, object-relational mapping module for Perl. It tries to be simple and flexible, and it is meant to integrate with your own custom classes.

As of version 0.04, it allows for multiple database connections and it features L<DBIx::Connector> objects under the hood to mantain them, which should make it easy to use in persistent environments.

There are many ORMs for Perl. Most notably, you should look at L<DBIx::Class> and L<DBIx::DataModel> which are two robust, proven offerings as of today. L<DBIx::Lite> is another light-weight alternative.

This module is in its infancy and it is very likely to change and (gasp) risk is high that it will go unmaintained.

=head1 DOCUMENTATION

The documentation is split into four parts:

=over

=item * This general view, which documents the umbrella class DBIx::Mint. A DBIx::Mint object encapsulates a given database conection and its schema. This class maintains a pool of named Mint objects.

=item * L<DBIx::Mint::Schema> documents relationships and the mapping between classes and database tables. It shows how to specify table names, primary keys and how to create associations between classes.

=item * L<DBIx::Mint::Table> is a role that implements methods that modify or fetch data from a single table. It is meant to be applied to your custom classes (via L<Moo>).

=item * L<DBIx::Mint::ResultSet> builds database queries using chainable methods. It does not know about the schema, so it can be used without one. Internally, ResultSet objects are used to implement fetch methods and class associations, for example.

=back

=head1 GENERALITIES

The basic idea is that, frequently, a class can be mapped to a database table. Records become objects that can be created, fetched, updated and deleted. Relationships between tables/classes can also be represented as class methods that fetch or insert objects from other classes, for example, or that simply return data. So, with the help of a schema, a given class could know what table in a database it represents, as well as its primary keys and the relationships it has with other classes. Using such a schema and a table-accessing role, our class gains database persistence. This side of the ORM is clearly class-based and it is implemented in L<DBIx::Mint::Table>.

Fetching data from joined tables is different, though. While you can have a class to represent records comming from a join, you cannot create, update or delete directly the objects from such a class. Using L<DBIx::Mint::ResultSet> objects, complex table joins and queries are encapsulated, along with different options to actually fetch data and possibly inflate it into full-blown objects. In this case, DBIx::Mint uses the result set approach, as DBIx::Lite does.

Finally, the database connection, the database schema and its SQL syntax details are encapsulated in DBIx::Mint objects. You can create more than one of such objects to access more than one database within your program. Mint objects are kept in a centralized pool so that they remain accessible without the need of passing them through explicitly. 

=head1 SUBROUTINES/METHODS IMPLEMENTED BY L<DBIx::Mint>

=head2 new

Object constructor. It will save the newly created object into the connection pool, but it will croak if the object exists already. All its arguments are optional:

=over

=item name

The name of the new Mint object. It will be used to fetch the object from the connections pool (see L<DBIx::Mint::instance>).

=item schema

An already built L<DBIx::Mint::Schema> object. Useful to re-use the same schema over different database connections.

=item abstract

A L<SQL::Abstract::More> object. By default, DBIx::Mint uses all its default options.

=item connector

A L<DBIx::Connector> object. By default, DBIx::Mint uses all its default options.

=back

=head2 connect

This is a method that receives your database connection parameters per L<DBI>'s spec and instantiates the L<DBIx::Connector> object:

 # Create the default Mint object and its connection:
 DBIx::Mint->connect('dbi:SQLite:dbname=t/bloodbowl.db', '', '',
        { AutoCommit => 1, RaiseError => 1 });

 # Create a named connection:
 my $mint = DBIx::Mint->new( name => 'other' );
 $mint->connect('dbi:SQLite:dbname=t/bloodbowl.db', '', '',
        { AutoCommit => 1, RaiseError => 1 });

=head2 instance

Returns an instance of L<DBIx::Mint>:

 my $mint  = DBIx::Mint->instance;           # Default connection
 my $mint2 = DBIx::Mint->instance('other');  # 'other' connection

=head2 connector

This accessor/mutator will return the underlying L<DBIx::Connector> object.

=head2 dbh

This method will simply return the database handle from L<DBIx::Connector>, which is guaranteed to be alive.
 
=head2 abstract

This is the accessor/mutator for the L<SQL::Abstract::More> subjacent object.

=head2 schema

This is the accessor/mutator for the L<DBIx::Mint::Schema> instance:

=head2 do_transaction

This instance method will take a code reference and execute it within a transaction block. In case the transaction fails (your code dies) it is rolled back and B<a warning is thrown>. In this case, L<do_transaction> will return C<undef>. If successful, the transaction will be commited and the method will return a true value. 

 $mint->do_transaction( $code_ref ) || die "Transaction failed!";

Note that it must be called as an intance method, not as a class method. The right database connection will be used.
 
=head1 USE OF L<DBIx::Connector>

Under the hood, DBIx::Mint uses DBIx::Connector to hold the database handle and to make sure that the connection is well and alive when you need it. The database modification routines employ the 'fixup' mode for modifying the database at a very fine-grained level, so that no side-effects are visible. This allows us to use DBIx::Connector in the most efficient way. However, please pay attention when installing method modifiers around those methods provided by the L<DBIx::Mint::Table> role. In this case, unwanted have secondary effects are possible.

The query routines offered by L<DBIx::Mint::ResultSet> use the 'fixup' mode while retrieving the statement holder with the SELECT query already prepared, but not while extracting information in the execution phase. If you fear that the database connection may have died in the meantime, you can always use Mint's C<connector> method to get a hold of the DBIx::Connector object and manage the whole query process yourself. This should not be necessary, though.

=head1 DEPENDENCIES

This distribution depends on the following external, non-core modules:

=over

=item Moo

=item SQL::Abstract::More

=item DBI

=item DBIx::Connector

=item List::MoreUtils

=item Clone

=back

=head1 BUGS AND LIMITATIONS

Testing is not complete; in particular, tests look mostly for the expected results and not for edge cases or plain incorrect input. 

Please report problems to the author. Patches are welcome. Tests are welcome also.

=head1 ACKNOWLEDGEMENTS

The ResultSet class was inspired by L<DBIx::Lite>, by Alessandro Ranellucci.

=head1 AUTHOR

Julio Fraire, <julio.fraire@gmail.com>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2013, Julio Fraire. All rights reserved.

=head1 LICENSE

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
