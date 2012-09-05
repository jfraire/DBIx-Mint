package DBIx::Mint::ResultSet::Iterator;

use Moo;

has closure => ( is => 'ro', required => 1 );

sub next {
    my $self = shift;
    return $closure->();
}

1;
