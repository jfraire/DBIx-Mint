use ExtUtils::MakeMaker;
use strict;
use warnings;
use v5.10;

WriteMakefile(
    NAME              => 'DBIx::Mint',
    VERSION_FROM      => 'lib/DBIx/Mint.pm', # finds $VERSION
    PREREQ_PM         => {
        DBI                 =>   0,
        Moo                 => 1.0,
        MooX::Singleton     =>   0,
        SQL::Abstract::More =>   0,
        List::MoreUtils     =>   0,
        Clone               =>   0,
    },
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/DBIx/Mint.pm',
       AUTHOR         => 'Julio Fraire <julio.fraire@gmail.com>') : ()),
);
