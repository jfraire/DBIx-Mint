package DBIx::Mint::Schema::Class;
use Moo;

has class      => ( is => 'ro', required => 1 );
has table      => ( is => 'ro', required => 1 );
has pk         => ( is => 'ro', required => 1 );
has auto_pk    => ( is => 'ro' );

sub BUILDARGS {
    my ($class, %args) = @_;
    $args{pk} = [ $args{pk} ] unless ref $args{pk};
    return \%args;
}

1;
