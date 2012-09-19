package DBIx::Mint::Schema;

use DBIx::Mint::ResultSet;
use DBIx::Mint::Schema::Class;
use Carp;
use v5.10;
use Moo;
with 'MooX::Singleton';

has classes       => ( is => 'rw', default => sub {{}} );
has tables        => ( is => 'rw', default => sub {{}} );

sub add_class {
    my $self  = shift;
    my $class = DBIx::Mint::Schema::Class->new(@_);
    $self->classes->{$class->class}       = $class;
    $self->tables->{ $class->table}       = $class;
}

sub for_class {
    my ($self, $class) = @_;
    return $self->classes->{$class};
}

sub for_table {
    my ($self, $table) = @_;
    return $self->tables->{$table};
}

sub one_to_many {
    my ($schema, %params) = @_;

    my $conditions  = $params{ conditions }     || croak "one_to_many: join conditions are required";
    my $method      = $params{ method     }     || croak "one_to_many: method name is required";
    my $inv_method  = $params{ inverse_method } || undef;
    my $insert_into = $params{ insert_into }    || undef;
    
    $schema->add_relationship(result_as => 'all', inv_result_as => 'single', %params);

    return 1;
}

sub many_to_many {
    my ($schema, %params) = @_; 
    
    my $conditions  = $params{ conditions }     || croak "many_to_many: join conditions are required";
    my $method      = $params{ method     }     || croak "many_to_many: method name is required";
    my $inv_method  = $params{ inverse_method } || undef;
    croak "insert_into is not supported for many_to_many relationships" if $params{insert_into};
    
    $schema->add_relationship(result_as => 'all', inv_result_as => 'all', %params);

    return 1;
}

sub add_relationship {
    my ($schema, %params) = @_;
    
    # Support for from_class, to_class alternative (mainly for one-to-one associations)
    if ($params{from_class} && $params{conditions}) {
        $params{conditions} = [ $params{from_class}, $params{conditions}, $params{to_class}];
    }

    if ($params{from_class} && ! exists $params{conditions}) {
        my $pk = $schema->for_class( $params{from_class} )->pk->[0];
        $params{conditions} = [ $params{from_class}, { $pk => $params{to_field} }, $params{to_class} ];
    }
    
    
    my $conditions      = $params{ conditions }     || croak "add_relationship: join conditions are required";
    my $method          = $params{ method     }     || croak "add_relationship: method name is required";
    my $inv_method      = $params{ inverse_method } || undef;
    my $insert_into     = $params{ insert_into }    || undef;
    my $inv_insert_into = $params{ inv_insert_into} || undef;
    my $result_as       = $params{ result_as }      || undef;
    my $inv_result_as   = $params{ inv_result_as }  || undef;

    # Create method into $from_class
    my $from_class = $conditions->[0];
    my $rs = $schema->_build_rs(@$conditions);
    $schema->_build_method($rs, $from_class, $method, $result_as);
    
    # Create method into $target_class
    if (defined $inv_method) {
        my @cond_copy    = map { ref $_ ? { reverse %$_ } : $_ } reverse @$conditions;
        my $target_class = $cond_copy[0];
        my $inv_rs       = $schema->_build_rs(@cond_copy);
        $schema->_build_method($inv_rs, $target_class, $inv_method, $inv_result_as);
    }
    
    # Create insert_into method
    if (defined $insert_into) {
        my $join_cond    = $conditions->[1];
        my $target_class = $conditions->[2];
        $schema->_build_insert_into($from_class, $target_class, $insert_into, $join_cond);
    }

    return 1;
}

sub _build_rs {
    my ($schema, @conditions) = @_;
    my $from_class  = shift @conditions;
    my $from_table  = 'me';
    my $to_table;
    
    my $rs = DBIx::Mint::ResultSet->new( table => $schema->for_class( $from_class )->table  );
    
    do {
        my $from_to_fields = shift @conditions;
        my $to_class       = shift @conditions;
        my $class_obj      = $schema->for_class($to_class) || croak "Class $to_class has not been defined";
        $to_table          = $class_obj->table;
        my %join_conditions;
        while (my ($from, $to) = each %$from_to_fields) { 
            $from = "$from_table.$from"   unless $from =~ /\./;
            $to   = "$to_table.$to"       unless $to   =~ /\./;
            $join_conditions{$from} = $to;
        }
        $rs = $rs->inner_join( $to_table, \%join_conditions );
        $from_table = $to_table;
    }
    while (@conditions);
    
    return $rs->select( $to_table . '.*')->set_target_class( $schema->for_table($to_table)->class );
}

sub _build_method {
    my ($schema, $rs, $class, $method, $result_as) = @_; 
    
    my @pk = @{ $schema->for_class($class)->pk };
    
    {
        no strict 'refs';
        *{$class . '::' . $method} = sub { 
            my $self = shift;
            my %conditions;
            $conditions{"me.$_"} = $self->$_ foreach @pk;
            my $rs_copy = $rs->search(\%conditions);
            given ( $result_as ) {
                when ('single')       { return $rs_copy->single;      }
                when ('all')          { return $rs_copy->all;         }
                when ('as_iterator')  { return $rs_copy->as_iterator; }
                when ('as_sql')       { return $rs_copy->select_sql;  }
                default               { return $rs_copy;              }
            }
        };
    }
}


sub _build_insert_into {
    my ($schema, $class, $target, $method, $conditions) = @_;
            
    no strict 'refs';
    *{$class . '::' . $method} = sub {
        my $self   = shift;
        my @copies;
        foreach my $record (@_) {
            while (my ($from_field, $to_field) = each %$conditions) {
                croak $class . "::" . $method .": $from_field is not defined" 
                    if !defined $self->{$from_field};
                $record->{$to_field} = $self->{$from_field};
            }
            push @copies, $record;
        }
        return $target->insert(@copies);
    };
    return 1;
}

1;
