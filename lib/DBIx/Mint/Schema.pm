package DBIx::Mint::Schema;

use DBIx::Mint::ResultSet;
use DBIx::Mint::Schema::Class;
use DBIx::Mint::Schema::Relationship;
use v5.10;
use Moo;
with 'MooX::Singleton';

has classes       => ( is => 'rw', default => sub {{}} );
has tables        => ( is => 'rw', default => sub {{}} );
has relationships => ( is => 'rw', default => sub {{}} );

sub add_class {
    my $self  = shift;
    my $class = DBIx::Mint::Schema::Class->new(@_);
    $self->classes->{$class->class}       = $class;
    $self->tables->{ $class->table}       = $class;
    $self->relationships->{$class->class} = {};
}

sub for_class {
    my ($self, $class) = @_;
    return $self->classes->{$class};
}

sub for_table {
    my ($self, $table) = @_;
    return $self->tables->{$table};
}

sub add_relationship {
    my $schema = shift;
    my $rel    = DBIx::Mint::Schema::Relationship->new(@_);
    
    my $from = $schema->for_class( $rel->from_class);
    my $to   = $schema->for_class( $rel->to_class  );
    
    {
        # Build method for the "from" class (returns many records)
        my $class = $from->class;
        my @pk = @{ $from->pk };
        my $rs = DBIx::Mint::ResultSet->new( table => $from->table )
            ->select          ( $to->table . '.*'            )
            ->inner_join      ( $to->table, $rel->conditions )
            ->set_target_class( $rel->to_class               );
            
        no strict 'refs';
        *{$class . '::' . $rel->method} = sub { 
            my $self = shift;
            my %conditions;
            $conditions{"me.$_"} = $self->$_ foreach @pk;
            $rs = $rs->search(\%conditions);
            given ( $rel->result_as ) {
                when ('single')       { return $rs->single;      }
                when ('resultset')    { return $rs;              }
                when ('as_iterator')  { return $rs->as_iterator; }
                default               { return $rs->all;         }
            }
        };
    }
    
    if ( $rel->has_inverse_method ) {
        my $class = $to->class;
        my @pk = @{ $to->pk };
        my $inverse_rs = DBIx::Mint::ResultSet->new( table => $to->table )
            ->select          ( $from->table . '.*'                    )
            ->inner_join      ( $from->table, $rel->inverse_conditions )
            ->set_target_class( $rel->from_class                       );
            
        no strict 'refs';
        *{$class . '::' . $rel->inverse_method} = sub {
            # Build method for the "to" class (returns one record)
            my $self = shift;
            my %conditions;
            $conditions{"me.$_"} = $self->$_ foreach @pk;
            
            $inverse_rs = $inverse_rs->search(\%conditions);
            given ( $rel->inverse_result_as ) {
                when ('all')          { return $inverse_rs->all;         }
                when ('resultset')    { return $inverse_rs;              }
                when ('as_iterator')  { return $inverse_rs->as_iterator; }
                default               { return $inverse_rs->single;      }
            }
        };
    }
    
    # if ( $rel->has_insert_into ) {
        # my $method = 'insert_into_' . $rel->insert_into || $rel->method;
        
# #         # Our ResultSet must have the ability to insert

# #         no strict 'refs';
        # *{"$class::$method"} =sub {
            # my $self = shift;
            
# #             # We should receive a list of hash refs/objects for this to work
            
# #         };
    # }
}

1;
