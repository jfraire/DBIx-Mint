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

sub find_or_create {}

1;
