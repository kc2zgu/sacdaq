package SensLog;

use strict;
use IO::File;

sub new {
    my ($class, $path) = @_;

    my $self = {logpath => $path, fh => undef, file => undef};

    bless $self, $class;
}

sub open {
    my ($self, $file) = @_;

    if (!defined ($self->{file}))
    {
        print "Log not open\n";
        $self->{fh} = IO::File->new("$self->{logpath}/$file", 'a');
        $self->{file} = $file;
        print "Opened log $file\n";
    }
    else
    {
        if ($self->{file} ne $file)
        {
            $self->{fh}->close;
            $self->{fh} = IO::File->new("$self->{logpath}/$file", 'a');
            $self->{file} = $file;
            print "Opened log $file\n";
        }
    }
}

sub write_report {
    my ($self, $report) = @_;

    for my $k(sort keys %$report)
    {
        $self->{fh}->print("$k: $report->{$k}\n");
    }
    $self->{fh}->print("\n");
    $self->{fh}->flush;
}


1;
