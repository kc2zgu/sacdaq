#!/usr/bin/perl

use strict;

use FindBin;
use lib "$FindBin::Bin/lib";

use SensInstance;

my ($driver, @args) = @ARGV;

my $sensor = SensInstance->new_direct($driver, @args);

my $report = $sensor->report;

for my $key(sort keys %$report)
  {
    print "$key=$report->{$key}\n";
  }
