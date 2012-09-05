package DBIx::Mint::ResultSet;

use DBIx::Mint;
use List::MoreUtils qw(uniq);
use Clone qw(clone);
use Carp;
use Moo;

has table         => ( is => 'rw', required  => 1 );
has target_class  => ( is => 'rw', predicate => 1 );
has columns       => ( is => 'rw', default   => sub {[]});
has where         => ( is => 'rw', default   => sub {[]});
has joins         => ( is => 'rw', default   => sub {[]});

has rows_per_page => ( is => 'rw', default   => sub {10} );
has limit         => ( is => 'rw', predicate => 1 );
has offset        => ( is => 'rw', predicate => 1 );

has list_group_by => ( is => 'rw', default   => sub {[]});
has list_having   => ( is => 'rw', default   => sub {[]});
has list_order_by => ( is => 'rw', default   => sub {[]});

has iterator      => ( is => 'rw', predicate => 1, handles => ['next'] );

around 'select', 'search', 'group_by', 'having', 'order_by', 'target_class', 
    'set_limit', 'set_offset', 'set_rows_per_page' => sub {
    my $orig = shift;
    my $self = shift;
    my $clone = $self->_clone;
    $clone->$orig(@_);
    return $clone;
};

sub _clone {
    my $self = shift;
    return clone $self;
}


# Query building pieces

sub select {
    my $self = shift;
    push @{ $self->columns }, @_;
}

sub search {
    my $self = shift;
    push @{ $self->where }, @_;
}

sub group_by {
    my $self = shift;
    push @{ $self->list_group_by }, @_;
}

sub having {
    my $self = shift;
    push @{ $self->list_having }, @_;
}

sub order_by {
    my $self = shift;
    push @{ $self->list_order_by }, @_;
}

sub page {
    my ($self, $page) = @_;
    $page = defined $page ? $page : 1;
    return $self->set_limit ( $self->rows_per_page )
         ->set_offset($self->rows_per_page * ( $page - 1 ));
}

sub set_limit {
    my ($self, $value) = @_;
    $self->limit($value);
}

sub set_offset {
    my ($self, $value) = @_;
    $self->offset($value);
}

sub set_rows_per_page {
    my ($self, $value) = @_;
    $self->rows_per_page($value);
}

# Joins
# Input:
#   table      (array ref):        [name, alias] or name
#   conditions (array of hashes):  [{ left_field => 'right_field' }

sub inner_join {
    my $self = shift;
    return $self->_join('<=>', @_);
}

sub left_join {
    my $self = shift;
    return $self->_join('=>', @_);
}

sub _join {
    my $self   = shift;
    my ($operation, $table, $conditions) = @_;
    my $table_name;
    my $table_alias;
    $conditions = [$conditions] unless ref $conditions eq 'ARRAY';
    if (ref $table) {
        ($table_name, $table_alias) = @$table;
    }
    else {
        $table_name  = $table;
        $table_alias = $table;
    }

    my $new_self = $self->_clone;
    my @join_conditions;
    foreach my $condition (@$conditions) {
        my ($field1, $field2) = each %$condition;
        if ($field1 !~ /\./) {
            $field1 = "me.$field1";
        }
        if ($field2 !~ /\./) {
            $field2 = "$table_alias.$field2";
        }
        push @join_conditions, "$field1=$field2";
    }
    push @{$new_self->joins}, $operation . join(',', @join_conditions), join('|', $table_name, $table_alias);    
    return $new_self;
}

sub select_sql {
    my $self = shift;
    
    # columns
    my @cols  = @{$self->columns} ? uniq(@{$self->columns}) : ('*');
    
    # joins    
    my @joins = ($self->table.'|'.'me', @{$self->joins});
    
    return DBIx::Mint->instance->abstract->select(
        -columns    => \@cols,
        -from       => [ -join => @joins ],
        -where      => [ -and  => $self->where ],
        $self->has_limit           ? (-limit       => $self->limit)           : (),
        $self->has_offset          ? (-offset      => $self->offset)          : (),
        @{$self->list_group_by}    ? (-group_by    => $self->list_group_by)   : (),
        @{$self->list_having}      ? (-having      => $self->list_having)     : (),
        @{$self->list_order_by}    ? (-order_by    => $self->list_order_by)   : (),
    );
}

sub select_sth {
    my $self = shift;
    my $mint = DBIx::Mint->instance;
    croak "The database handle has not been established" unless $mint->has_dbh;
    my ($sql, @bind) = $self->select_sql;
    return DBIx::Mint->instance->dbh->prepare($sql), @bind;
}


# Fetching data

# Returns an array of inflated objects
sub all {
    my $self = shift;
    my ($sth, @bind) = $self->select_sth;
    $sth->execute(@bind);
    my $all = $sth->fetchall_arrayref({});
    return map { $self->inflate($_) } @$all;
}

# Returns a single, inflated object
sub single {
    my $self = shift;
    my ($sth, @bind) = $self->set_limit(1)->select_sth;
    $sth->execute(@bind);
    my $single = $sth->fetchrow_hashref;
    $sth->finish;
    return $self->inflate($single);
}

# Returns a number
sub count {
    my $self  = shift;
    my $clone = $self->_clone;
    $clone->columns([]);
    my ($sth, @bind) = $clone->select('COUNT(*)')->select_sth;
    $sth->execute(@bind);
    return $sth->selectall_arrayref->[0][0];
}

# Creates an iterator and saves it into the ResultSet object
sub as_iterator {
    my $self         = shift;
    my ($sth, @bind) = $self->select_sth;
    $sth->execute(@bind);
    
    my $iterator = DBIx::Mint::ResultSet::Iterator->new(
        closure => sub { return $self->inflate($sth->fetchrow_hashref); },
    );
    
    $self->iterator( $iterator );
}

# Simply blesses the fetched row into the target class
sub inflate {
    my ($self, $row) = @_;
    return undef unless defined $row;
    return $row  unless $self->has_target_class;
    return bless  $row, $self->target_class;
}

1;

