package DBIx::Mint;

use DBIx::Mint::Schema;
use SQL::Abstract::More;
use Carp;
use Moo;
with 'MooX::Singleton';

our $VERSION = 0.01;

has abstract => (
    is      => 'rw',
    default => sub {
        SQL::Abstract::More->new();
    },
);

has dbh    => ( is => 'rw', predicate => 1 );

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

DBIx::Mint - A light-weight ORM without accessor generation


=head1 VERSION

This documentation refers to 

DBIx::Mint 0.01

=head1 SYNOPSIS

Without a schema you can only fetch data. No data modification methods are offered:
 
 use DBIx::Mint;
 use DBI;
 
 # Connect to the database
 my $dbh  = DBI->connect(...);
 my $mint = DBIx::Mint->instance( dbh => $dbh );
 
 # Without a schema, you can use the DBIx::Mint::ResultSet class
 my $rs = DBIx::Mint::ResultSet->new( table => 'coaches' );
 
 # Joins. This will retrieve all the players for coach #1
 my @team_players = $rs->search( { 'me.id' => 1 } )
                       ->inner_join('teams',    { 'me.id'    => 'coach' })
                       ->inner_join( 'players', { 'teams.id' => 'team'  })
                       ->all;

See the docs for L<DBIx::Mint::ResultSet> for all the methods you can use.

Once you add a schema you can add relationships and you can modify data.

Somewhere in your code you have defined your classes, with all of your business logic:

 package Bloodbowl::Team;
 use Moo;
 with 'DBIx::Mint::Table';
 
 has id   => (is => 'rw' );
 has name => (is => 'rw' );
 ...

 my $schema = $mint->schema;
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
     is_auto_pk => 1,
 );
 
 # This is a one-to-many relationship
 $schema->add_relationship(
     from_class     => 'Bloodbowl::Team',
     to_class       => 'Bloodbowl::Player',
     to_field       => 'team',
     method         => 'get_players',
     inverse_method => 'get_team',
 );
 
 my $team = Bloodbowl::Team->find(1);
 my @players = $team->get_players;
 
 # Database modification methods include insert, update, and delete.
 # They act on a single object when called as instance methods
 # but over the whole table if called as class methods:
 $team->name('Los Invencibles');
 $team->update;
 
 Bloodbowl::Coach->update({ status => 'suspended' }, { password => 'blocked' });
 
In this case, you can get the full documentation by looking at L<DBIx::Mint::Schema> and L<DBIx::Mint::Table>. 
 
 
=head1 DESCRIPTION

Yet another object-relational mapping module for Perl. Its goals are:

=over

=item * To provide flexible, chaineable methods to fetch data from a database

=item * To provide a flexible, powerful way to build relationships between classes

=item * It does not generate accessors, so you can use it on top of your existing classes

=item * To be light on dependencies

=back

On the other side of the equation, it has some strong restrictions:

=over

=item * It supports a single database handle

=item * While it uses roles (through Role::Tiny), it does put a lot of methods on your namespace

=item * It only uses DBI for the database connection and it makes no effort to keep it alive for long-running processes.

=back

There are many ORMs for Perl. Most notably, you should look at L<DBIx::Class> and L<DBIx::DataModel>. L<DBIx::Lite> is a light-weight alternative to those two, enterprise-level ORMs.

Note that this module is in its infancy and it is very likely to change or (gasp) go unmaintained.

=head1 DOCUMENTATION

The documentation is split in three parts:

=over

=item * This general view

=item * L<DBIx::Mint::Schema> documents relationships and the mapping between classes and database tables. Look there to find out how to specify table names, primary keys and how to create associations between classes.

=item * L<DBIx::Mint::ResultSet> is the API to fetch information from the database. Internally, associations are implemented using ResultSet objects.

=back

=head1 SUBROUTINES/METHODS

This module offers a just a few starting methods:

=head2 instance

Returns an instance of DBIx::Mint. It is a singleton, so you can access it from anywhere. To make it useful you should give it a database handle.

=head2 dbh

This is the accessor/mutator of the database handle. To give DBIx::Mint a database connection, do:

 # Connect to the database
 my $dbh  = DBI->connect(...);
 my $mint = DBIx::Mint->instance( dbh => $dbh );
 
or:

 $mint->dbh( $dbh );
 
=head2 abstract

This is the accessor/mutator of the L<SQL::Abstract::More> subjacent object. You can choose to build your own object with the parameters you need and then simply stuff it into your DBIx::Mint instance:

 my $sql = SQL::Abstract::More->new(...);
 $mint->abstract($sql);

=head2 schema

This is simply a method that will return your L<DBIx::Mint::Schema> instance:

 my $schema = $mint->schema;

=head2 do_transaction

This method will take a code reference and execute it within a transaction block. In case the transaction fails (your code dies) it is rolled back and B<a warning is thrown>. In this case, L<do_transaction> will return C<undef>. If successful, the transaction will be commited and the method will return a true value.

 $mint->do_transaction( $code_ref ) || die "Transaction failed!";

=head1 DIAGNOSTICS

=over

=item Transaction failed

This means that the code reference run in a transaction died. This is just a warning; you should check the return value of C<do_transaction>.

=back



=head1 CONFIGURATION AND ENVIRONMENT

A full explanation of any configuration system(s) used by the module,
including the names and locations of any configuration files, and the
meaning of any environment variables or properties that can be set. These
descriptions must also include details of any configuration language used.
(See also "Configuration Files" in Chapter 19.)


=head1 DEPENDENCIES

A list of all the other modules that this module relies upon, including any
restrictions on versions, and an indication of whether these required modules are
part of the standard Perl distribution, part of the module's distribution,
or must be installed separately.


=head1 INCOMPATIBILITIES

A list of any modules that this module cannot be used in conjunction with.
This may be due to name conflicts in the interface, or competition for
system or program resources, or due to internal limitations of Perl
(for example, many modules that use source code filters are mutually
incompatible).


=head1 BUGS AND LIMITATIONS

A list of known problems with the module, together with some indication of
whether they are likely to be fixed in an upcoming release.

Also a list of restrictions on the features the module does provide:
data types that cannot be handled, performance issues and the circumstances
in which they may arise, practical limitations on the size of data sets,
special cases that are not (yet) handled, etc.

The initial template usually just has:



There are no known bugs in this module.
Please report problems to 

<Maintainer name(s)>

  (

<contact address>

)
Patches are welcome.

=head1 ACKNOWLEDGEMENTS

This module is heavily based on L<DBIx::Lite>, by Alessandro Ranellucci. The benefits of that module over DBIx::Mint are that it does provide accessors and it does allow for record modifications without using a schema. The main benefits of this module over DBIx::Lite is that relationships are more flexible, and you are allowed to have more than one relationships between two tables.

=head1 AUTHOR

<Author name(s)>

 (

<contact address>

)

=head1 LICENCE AND COPYRIGHT

Copyright (c) 

<year> <copyright holder>

 (

<contact address>

). All rights reserved.

followed by whatever licence you wish to release it under.
For Perl code that is often just:



This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

=cut
