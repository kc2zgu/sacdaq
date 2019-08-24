#!/usr/bin/perl

use strict;

use FindBin;
use lib "$FindBin::Bin/lib";

use DimValue;

my $dv = DimValue->new(VALUE => $ARGV[0], UNIT => $ARGV[1]);

my $fval = $dv->format;

print "Input value: $fval\n";

my $cval = $dv->convert_format($ARGV[2]);

print "Converted: $cval\n";
