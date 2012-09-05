#!/usr/bin/perl

use Test::More;
use strict;
use warnings;

BEGIN {
    use_ok 'DBIx::Mint';
    use_ok 'DBIx::Mint::ResultSet';
}

my $mint = DBIx::Mint->instance;
isa_ok($mint, 'DBIx::Mint');

my $rs = DBIx::Mint::ResultSet->new(
    table => 'craters',
);
isa_ok($rs, 'DBIx::Mint::ResultSet');

# Tests for joining tables
{
    my $new_rs = $rs->inner_join(['table2','t2'], {  field1 => 't2.field2' })
                    ->left_join (['table3','t3'], {  field2 => 'field1'    });
    isa_ok($new_rs, 'DBIx::Mint::ResultSet');
    my ($sql, @bind) = $new_rs->select_sql;
    like( $sql, qr{FROM craters AS me INNER JOIN table2 AS t2 ON \( me\.field1 = t2\.field2 \) LEFT OUTER JOIN table3 AS t3 ON \( me\.field2 = t3\.field1 \)},
        'SQL from joined tables set correctly');
}
{
    my $new_rs = $rs->inner_join(['table2','t2'], [{ 't2.field1' => 'me.field2' }, { 'me.field3' => 't2.field4' }]);
    isa_ok($new_rs, 'DBIx::Mint::ResultSet');
    my ($sql,@bind) = $new_rs->select_sql;
    like( $sql, qr{SELECT \* FROM craters AS me INNER JOIN table2 AS t2 ON \( \( me\.field3 = t2\.field4 AND t2\.field1 = me\.field2 \) \)},
        'SQL from joined tables with multiple conditions set correctly');
}

# Tests for selecting columns (add_columns)
{
    my ($sql, @bind) = $rs->select_sql;
    like($sql, qr{SELECT \* FROM craters AS me},
        'Not specifying columns works as expected');
}

{
    my $newrs = $rs->select( qw{field1|F1 field2} );
    isa_ok($newrs, 'DBIx::Mint::ResultSet');
    my ($sql, @bind) = $newrs->select_sql;
    like($sql, qr{SELECT field1 AS F1, field2 FROM craters AS me},
        'Selecting columns works as expected');
}

# Tests for where clauses (add_conditions)
{
    my ($sql, @bind) = $rs->search({ name => 'Copernicus'})->select_sql;
    like($sql, qr{SELECT \* FROM craters AS me WHERE \( name = \? \)},
        'Added a condition to the where clause');
}
{
    my ($sql, @bind) = $rs->search({ name => 'Copernicus'})
                          ->search({ field1 => [1,2]})
                          ->select_sql;
    like($sql, qr{SELECT \* FROM craters AS me WHERE \( \( name = \? AND \( field1 = \? OR field1 = \? \) \) \)},
        'Added two independent conditions to the where clause');
}    

done_testing();
