package DBIx::Mint::Table;

use DBIx::Mint::Schema;
use Carp;
use Role::Tiny;

# Methods that insert data
sub create {
    my $class = shift;
    my $obj   = $class->new(@_);
    $obj->insert;
    return $obj;
}

sub insert {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;
    my $schema = DBIx::Mint::Schema->instance->for_class($class)
        || croak "A schema definition for class $class is needed to use DBIx::Mint::Table";
    my $prim_key = $schema->pk->[0];
    
    # Build SQL insert statement
    my $data;
    if (!@_) {
        # Inserting an object
        $data = _remove_fields($schema, $proto);
    }
    elsif (ref $_[0]) {
        # Inserting a set of objects
        $data = _remove_fields($schema, $_[0]);
    }
    else {
        # Called as class method for a single object (not a ref)
        eval { $data = {@_} };
        croak "Arguments to insert must be key, value pairs while trying to insert an object"
            if $@;
        $data  = _remove_fields($schema, { @_ });
    }
    my ($fields, $values) = _sort_and_quote_hash($data);
    

    my $sql = sprintf 'INSERT INTO %s (%s) VALUES (%s)',
        $schema->table, join(', ', @$fields), join(', ',('?')x@$values);
   
    # Get sth
    my $dbh = DBIx::Mint->instance->dbh;
    my $sth = $dbh->prepare($sql);
    
    # Execute
    my @ids;
    if (ref $_[0]) {
        # Inserting a set of objects
        while (my $obj = shift @_) {
            my $copy = _remove_fields($schema, $obj);
            my ($obj_fields, $obj_values) = _sort_and_quote_hash($copy);
            croak "Insert failed: All objects must have the same fields"
                unless @$obj_fields ~~ @$fields;
            $sth->execute(@$obj_values);
            if ($schema->auto_pk) {
                my $id = $dbh->last_insert_id(undef, undef, $schema->table, $prim_key);
                $obj->{$prim_key} = $id;
            }
            push @ids, @$obj{ @{ $schema->pk } }; 
        }
    }
    else {
        # Inserting a single object
        $sth->execute(@$values);
        if ($schema->auto_pk) {
            my $id = $dbh->last_insert_id(undef, undef, $schema->table, $prim_key);
            $proto->{$prim_key} = $id if ref $proto;
            push @ids, $id;
        }
        else {
            push @ids, @$data{ @{ $schema->pk } };
        }
    }
    return wantarray ? @ids : $ids[0];
}

sub update {
    my $proto = shift;
    my $class = ref $proto ? ref $proto : $proto;
    my $schema = DBIx::Mint::Schema->instance->for_class($class)
        || croak "A schema definition for class $class is needed to use DBIx::Mint::ResourceSet::Table";

    # Build the SQL
    my ($sql, @bind);
    if (ref $proto) {
        # Updating a single object
        my @pk    = @{ $schema->pk };
        my %where = map { $_ => $proto->$_ } @pk;
        my %copy  = %$proto;
        delete $copy{$_} foreach @{ $schema->fields_not_in_db }, @pk;
        ($sql, @bind) = DBIx::Mint->instance->abstract->update($schema->table, \%copy, \%where);
    }
    else {
        # Updating at class level
        ($sql, @bind) = DBIx::Mint->instance->abstract->update($schema->table, $_[0], $_[1]);
    }
    
    # Execute the SQL
    return DBIx::Mint->instance->dbh->do($sql, undef, @bind);
}

sub delete {
    my $proto = $_[0];
    my $class = ref $proto ? ref $proto : $proto;
    my $schema = DBIx::Mint::Schema->instance->for_class($class)
        || croak "A schema definition for class $class is needed to use DBIx::Mint::Table";

    # Build the SQL
    my ($sql, @bind);
    if (ref $proto) {
        # Deleting a single object
        my @pk    = @{ $schema->pk };
        my %where = map { $_ => $proto->$_ } @pk;
        ($sql, @bind) = DBIx::Mint->instance->abstract->delete($schema->table, \%where);
    }
    else {
        # Deleting at class level
        ($sql, @bind) = DBIx::Mint->instance->abstract->delete($schema->table, $_[1]);
    }
    
    # Execute the SQL
    my $res = DBIx::Mint->instance->dbh->do($sql, undef, @bind);
    if (ref $proto && $res) {
        delete $proto->{$_} foreach (keys %$proto);
    }
    return $res;
}

# Returns a single, inflated object using its primary keys
sub find {
    my $class   = shift;
    croak "find must be called as a class method" if ref $class;
    
    my $schema = DBIx::Mint::Schema->instance->for_class($class);
    
    my $data;
    if (ref $_[0]) {
        $data = shift;
    }
    else {
        my @pk   = @{ $schema->pk };
        my %data;
        @data{@pk} = @_;
        $data = \%data;
    }

    my $table  = $schema->table;    
    my ($sql, @bind) = DBIx::Mint->instance->abstract->select($table, '*', $data);
    my $res = DBIx::Mint->instance->dbh->selectall_arrayref($sql, {Slice => {}}, @bind);
    
    return undef unless defined $res->[0];
    return bless $res->[0], $class;    
}

sub find_or_create {
    my $class = shift;
    my $obj   = $class->find(@_);
    $obj = $class->create(@_) if ! defined $obj;
    return $obj;
}

sub result_set {
    my $class = shift;
    my $schema = DBIx::Mint::Schema->instance->for_class($class);
    croak "result_set: The schema for $class is undefined" unless defined $schema;
    return DBIx::Mint::ResultSet->new( table => $schema->table );
}

sub _remove_fields {
    my ($schema, $record) = @_;
    my %data = %$record;
    delete $data{$_} foreach @{ $schema->fields_not_in_db };
    return \%data;
}

sub _sort_and_quote_hash {
    my $hash_ref = shift;
    my @sorted_keys   = sort keys %$hash_ref;
    my @quoted_keys   = map { DBIx::Mint->instance->dbh->quote_identifier( $_ ) } @sorted_keys;
    my @sorted_values =  @{$hash_ref}{@sorted_keys};
    return \@quoted_keys, \@sorted_values;
}

1;

=pod

=head1 NAME 

DBIx::Mint::Table - Role that maps a class to a table

=head1 SYNOPSIS

 # In your class:
 
 package Bloodbowl::Coach;
 use Moo;
 with 'DBIx::Mint::Table';
 
 has 'id'     => ( is => 'rwp', required => 1 );
 has 'name'   => ( is => 'ro',  required => 1 );
 ....
 
 # And in your schema:
 $schema->add_class(
    class   => 'Bloodbowl::Coach',
    table   => 'coaches',
    pk      => 'id',
    auto_pk => 1
 );
 
 # Finally, in your application:
 my $coach = Bloodbowl::Coach->find(3);
 say $coach->name;
 
 $coach->name('Will E. Coyote');
 $coach->update;
 
 my @ids = Bloodbowl::Coach->insert(
    { name => 'Coach 1' },
    { name => 'Coach 2' },
    { name => 'Coach 3' }
 );
 
 $coach->delete;
 
 my $coach = Bloodbowl::Coach->find_or_create(3);
 say $coach->id;
 
 # The following two lines are equivalent:
 my $rs = Bloodbowl::Coach->result_set;
 my $rs = DBIx::Mint::ResultSet->new( table => 'coaches' );

=head1 DESCRIPTION

This role allows your class to interact with a database table. It allows for record modification (insert, update and delete records) as well as data fetching via DBIx::Mint::ResultSet objects.

Database modification methods can be called as instance or class methods. In the first case, they act only on the calling object. When called as class methods they allow for the modification of several records.

Triggers can be added using the methods before, after, and around from L<Class::Method::Modifiers>. 

=head1 METHODS

=head2 insert

When called as a class method, it takes a list of hash references and inserts them into the table which corresponds to the calling class. The hash references must have the same keys to benefit from a prepared statement holder.

When called as an instance method, it inserts the data contained within the object into the database.

=head2 create

This methods is a convenience that calls new and insert to create a new object. The following two lines are equivalent:

 my $coach = Bloodbowl::Coach->create( name => 'Will E. Coyote');
 my $coach = Bloodbowl::Coach->new( name => 'Will E. Coyote')->insert;

=head2 update

When called as a class method it will act over the whole table. The first argument defines the change to update and the second, the conditions that the records must comply with to be updated:

 Bloodbowl::Coach->update( { email => 'unknown'}, { email => undef });
 
When called as an instance method it updates only the record that corresponds to the calling object:

 $coach->name('Mr. Will E. Coyote');
 $coach->update;

=head2 delete

This method deletes information from the corresponding table. Like insert and delete, if it is called as a class method it acts on the whole table; when called as an instance method it deletes the calling object from the database:

 Bloodbowl::Coach->delete({ email => undef });
 $coach->delete;

=head2 find

Fetches a single record from the database and blesses it into the calling class. It can be called as a class record only. It can as take as input either the values of the primary keys for the corresponding table or a hash reference with criteria to fetch a single record:

 my $coach_3 = Bloodbowl::Coach->find(3);
 my $coach_3 = Bloodbowl::Coach->find({ name => 'coach 3'});

=head2 find_or_create

This method will call 'create' if it cannot find a given record in the database.

=head1 SEE ALSO

This module is part of L<DBIx::Mint>.

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
 
