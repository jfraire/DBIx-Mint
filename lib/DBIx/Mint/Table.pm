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
        $data   = _remove_fields($schema, { @_ });
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
    my $table = DBIx::Mint::Schema->instance->for_class($class)->table;
    return DBIx::Mint::ResultSet->new( table => $table );
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
