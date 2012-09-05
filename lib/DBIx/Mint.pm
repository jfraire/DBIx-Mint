package DBIx::Mint;

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

has dbh => ( is => 'rw', predicate => 1 );

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

1;
