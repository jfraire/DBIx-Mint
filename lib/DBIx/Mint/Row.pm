package DBIx::Mint::Row;
use Moo::Role;

sub insert {}
sub insert_sth {}
sub insert_sql {}

sub update {}
sub update_sth {}
sub update_sql {}

sub delete {}
sub delete_sth {}
sub delete_sql {}

# Returns a single, inflated object using its primary keys
sub find {
    my $self    = shift;
    my ($where) = @_;
    if (!ref $where) {
        my @pk = @{ DBIx::Mint::Schema->instance->for_table($self->table)->pk };
        croak "DBIx::Mint::ResultSet requires a table and its primary key fields to find a row"
            unless @pk;
        $where =  [ -and => map { { shift(@pk) => $_ } } @_ ];
    }
    return $self->search($where)->single;
}

sub find_or_create {}



1;
