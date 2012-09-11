package DBIx::Mint::Schema::Relationship;

use DBIx::Mint::Schema;
use Carp;
use Moo;

has from_class           => ( is => 'ro', required  => 1 );
has to_class             => ( is => 'ro', required  => 1 );
has conditions           => ( is => 'rw', required  => 1 );

has method               => ( is => 'rw', required  => 1 );
has result_as            => ( is => 'rw', default => sub {'all'});
has insert_into          => ( is => 'rw', predicate => 1 );

has inverse_method       => ( is => 'rw', predicate => 1 );
has inverse_result_as    => ( is => 'rw', default => sub {'single'});

# Condition might be given in terms of a simple to_field.
# Ideally, it is an array ref of hash refs { from_attribute => to_attribute }.
sub BUILDARGS {
    my ($class, %args) = @_;
    
    if (exists $args{to_field}) {
        my $schema  = DBIx::Mint::Schema->instance;
        my $from_pk = $schema->for_class( $args{from_class} )->pk;
        croak 'DBIx::Mint::Schema cannot link automatically a class with multiple primary keys. '
            . 'Please define the conditions to join the two tables using \'conditions\'.'
            if scalar @$from_pk > 1;
        $args{conditions} = [{ $from_pk->[0] => delete $args{to_field} }];
    }

    return \%args;
}

sub inverse_conditions {
    my $self = shift;
    my %val;
    return [ map { { reverse %$_ } } @{ $self->conditions } ];
}

1;
