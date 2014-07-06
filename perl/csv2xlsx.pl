#!/usr/bin/perl -w
use strict;

##
# This script will combine csv files into
# xlsx worksheets and save a single xlsx file
#
# I used this script as a starting point:
# based on http://www.perlmonks.org/?node_id=635437
##

##
# TODO
#   - conf file option
#       file_get_hash_from_file('test.conf');
#   - print usage if unavailable option called
#   - second opt for copy/move should be the outfile basename and ext
#   - copy is not copying the file
##

use Excel::Writer::XLSX;
use Text::CSV::Simple;
use Getopt::Std;
use File::Basename;
use File::Copy qw(move copy);

my %options = ();
# f: use specified conf file
getopts("hdm:c:", \%options);

my $arg_count = scalar @ARGV;
usage() unless ($arg_count > 0);

my $theExt = '.xlsx';
my $filelist = shift @ARGV if ($arg_count > 0);
my $outfile = ($arg_count > 1) ? shift @ARGV : get_first_sheetname($filelist);
$outfile = verify_outfile_ext($outfile);

my @csvs = map +{ split /:/, $_ }, split /,/, $filelist;
check_files(@csvs);

# looks good.. we can start converting to xslx
my $parser = Text::CSV::Simple->new;
my $workbook = Excel::Writer::XLSX->new($outfile);
my $bold = $workbook->add_format();
$bold->set_bold(1);

# loop through csvs, get data, then build worksheet
foreach my $h (@csvs) {
    my ($file, $sheetName) = each %{$h};
    my @sheetData = $parser->read_file($file);
    build_worksheet($workbook, $sheetName, \@sheetData);

    # reset hash
    keys %{$h};
}

unless (-e $outfile) {
    die "conversion failed\n";
}

# print "delete csvs\n" if defined $options{d};
if (defined $options{d}) {
    foreach my $h (@csvs) {
        my $file = each %{$h};
        unlink $file if (-e $file);
    }
}

if (defined $options{c} && isDir($options{c})) {
    # TODO this is copying 0 bytes
    file_copy($outfile, $options{c} . '/' . $outfile);
    # copy($outfile, 'COPIED' . $theExt . '.');
}

if (defined $options{m} && isDir($options{m})) {
    file_move($outfile, $options{m} . '/' . $outfile);
}


sub usage {
    print "\033[1mUsage:\033[0m csv2xlsx [options] \"fileone.csv:sheetname,filetwo.csv:sheetname, etc\" [output_file_name]\n";
    print " options:\n";
    usage_options();
    exit;
}

sub usage_options {
    my %uopts = (
        h => 'make first row bold',
        d => 'delete csvs when xlsx is written',
        m => 'move xlsx to specified path',
    );

    my $firstColWidth = max_str_len_hash_key(\%uopts);
    my $pformat = '  %-' . ($firstColWidth + 4) . 's';

    foreach my $k (keys %uopts) {
        print "\033[1m";
        printf $pformat, '-' . $k;
        print "\033[0m";
        print $uopts{$k} . "\n";
    }
}

sub max_str_len_hash_key {
    my $hash = shift;
    my $max_len = 0;

    foreach my $str (keys %{$hash}) {
        $max_len = length $str unless (length $str < $max_len);
    }

    return $max_len;
}



sub file_exception {
    my $file = shift @_;
    print "File [$file] does not exist\n";
    exit;
}

sub check_files {
    my @files = @_;
    foreach my $h (@files) {
        my $file = each %{$h};
        file_exception($file) unless (-e $file);

        # reset hash
        keys %{$h};
    }
}

sub file_get_hash_from {
    my ($config_file) = @_;
    open FILE, '<' . $config_file or die "Unable to open $config_file: [$!]\n";
    my %hash = map { chomp; split /\|/; } <FILE>;
    close FILE;
    print "$_ => $hash{$_}\n" for keys %hash;
}

sub file_get_contents {
    my ($filename) = @_;
    open FILE, '<' . $filename or die "Unable to open file:$!\n";
    my @lines = <FILE>;
    close FILE;
    return @lines;
}

sub file_move {
    my $oldFile = shift;
    my $newFile = shift;
    move($oldFile, $newFile);
}

sub file_copy {
    my $oldFile = shift;
    my $newFile = shift;
    copy($oldFile, $newFile);
}

sub isDir {
    my $dir = shift;
    return -d $dir;
}

sub get_first_sheetname {
    my $input = shift;
    my ($filename) = ($input =~ /[-a-z0-9]+\.csv\:(.*?)\,/);
    $filename =~ s/ //g if ($filename);
    return $filename;
}

sub verify_outfile_ext {
    my $outfile = shift;
    my ($basename, $parentdir, $ext) = fileparse($outfile, qr/\.[^.]*$/);

    return $outfile if ($ext eq $theExt);
    return $outfile . $theExt if ($ext eq '');

    $outfile =~ s/$ext/$theExt/g if ($ext ne $theExt);
    return $outfile;
}

sub build_worksheet {
    my $workbook  = shift;
    my $worksheetName = shift;
    my $data = shift;
    my $rowNum = 0;
    my $qty = 0;

    my $worksheet = $workbook->add_worksheet($worksheetName);
    $worksheet->add_write_handler(qr[\w], \&store_string_widths);

    # write header to xlsx
    if (defined $options{h}) {
        my $headers = shift @{$data};
        $worksheet->write('A' . ++$rowNum, $headers, ,$bold);
    }

    # write data to xlsx
    foreach my $row (@{$data}) {
        $qty++;
        $worksheet->write($rowNum++, 0, $row);
    }

    autofit_columns($worksheet);
    warn "Convereted $qty rows.";
    return $worksheet;
}

######################################################################
#
# Adjust the column widths to fit the longest string in the column.
#
sub autofit_columns {

    my $worksheet = shift;
    my $col       = 0;

    for my $width (@{$worksheet->{__col_widths}}) {

        $worksheet->set_column($col, $col, $width) if $width;
        $col++;
    }
}

######################################################################
#
# The following function is a callback that was added via add_write_handler()
# above. It modifies the write() function so that it stores the maximum
# unwrapped width of a string in a column.
#
sub store_string_widths {
    my $worksheet = shift;
    my $col       = $_[1];
    my $token     = $_[2];

    # Ignore some tokens that we aren't interested in.
    return if not defined $token;       # Ignore undefs.
    return if $token eq '';             # Ignore blank cells.
    return if ref $token eq 'ARRAY';    # Ignore array refs.
    return if $token =~ /^=/;           # Ignore formula

    # Ignore numbers
    #return if $token =~ /^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/;

    # Ignore various internal and external hyperlinks. In a real scenario
    # you may wish to track the length of the optional strings used with
    # urls.
    return if $token =~ m{^[fh]tt?ps?://};
    return if $token =~ m{^mailto:};
    return if $token =~ m{^(?:in|ex)ternal:};

    # We store the string width as data in the Worksheet object. We use
    # a double underscore key name to avoid conflicts with future names.
    #
    my $old_width    = $worksheet->{__col_widths}->[$col];
    my $string_width = string_width($token);

    if (not defined $old_width or $string_width > $old_width) {
        # You may wish to set a minimum column width as follows.
        #return undef if $string_width < 10;

        $worksheet->{__col_widths}->[$col] = $string_width;
    }

    # Return control to write();
    return undef;
}


######################################################################
#
# Very simple conversion between string length and string width for Arial 10.
# See below for a more sophisticated method.
#
sub string_width {
    return length $_[0];
}
