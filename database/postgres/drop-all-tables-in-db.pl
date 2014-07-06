#!/usr/bin/perl -w
use strict;

##
# sometimes there is a database with
# a crap ton of tables that needs to
# be cleared out but not dropped
##

my $pgdb = 'dbname';
my $pguser = 'dbuser';

my $strTables = `psql $pgdb -t --command "SELECT string_agg(table_name, ',') FROM information_schema.tables WHERE table_schema='public'"`;
chomp($strTables);
chomp($strTables);
my @tables = split /\,/, $strTables;

foreach my $table (@tables) {
    my $droptable = 'psql -d ' . $pgdb . ' -U ' . $pguser . ' <<< "drop table ' . $table . ';"';
    print $droptable . "\n";
    system($droptable);
}
