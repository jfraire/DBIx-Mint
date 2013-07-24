package Bloodbowl::Coach;

use Moo;
with 'DBIx::Mint::Table';

has name     => ( is => 'ro', required => 1);
has email    => ( is => 'rw');
has password => ( is => 'rw');

1;
