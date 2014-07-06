#!/usr/bin/perl -w
use strict;
die "database name is required\n" if (scalar @ARGV == 0);

my ($dbname, $dbuser, $dropdb, $droprole, $dbquit) = '';

$dbname = shift;
$dbuser = shift if defined $ARGV[1];

unless (defined $dbuser) {
	$dbuser = $dbname . '_admin';
}

print " drop database: $dbname\n";
print " drop role: $dbuser\n";
# exit;

$dropdb = 'psql -d postgres <<< "drop database ' . $dbname . ';"';
# print "$dropdb\n";
system($dropdb);

$droprole = 'psql -d postgres <<< "drop user ' . $dbuser . ';"';
# print "$droprole\n";
system($droprole);

# quit psql
$dbquit = 'psql -d postgres <<< "\q"';
# print "$dbquit\n";
system($dbquit);
