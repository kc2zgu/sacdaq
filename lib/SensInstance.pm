package SensInstance;

use strict;

use YAML qw/LoadFile/;
use IPC::Run qw/run/;
use File::Slurp;
use UUID::Tiny ':std';
use FindBin;

sub new {
    my ($class, $conf) = @_;

    my $self = LoadFile($conf);

    return undef unless (defined $self->{driver} && defined $self->{name});

    $self->{args} = [] unless exists $self->{args};

    my $uuid;
    eval {$uuid = read_file("sensors.d/$self->{name}.uuid")};
    chomp $uuid;
    if (is_uuid_string($uuid))
    {
        $self->{uuid} = $uuid;
    }
    else
    {
        print "No UUID found\n";
        $uuid = create_uuid_as_string();
        $self->{uuid} = $uuid;
        write_file("sensors.d/$self->{name}.uuid", "$uuid\n");
    }
    print "UUID: $self->{uuid}\n";

    bless $self, $class;
}

sub report {
    my ($self, $time) = @_;

    my $drvpath = "$FindBin::Bin/drivers";
    my $libpath = "$FindBin::Bin/lib";
    my $driver = $self->{driver};

    my $drvfile = "$drvpath/$driver.pl";
    my %repvalues = ('SENSOR-NAME' => $self->{name}, 'SENSOR-UUID' => $self->{uuid}, TIME => $time);

    print "About to run $drvfile\n";
    if (-x $drvfile)
    {
        my $repdata;
        $ENV{PERL5LIB} = $libpath;
        run ["$drvfile", @{$self->{args}}], \undef, \$repdata;
        $repvalues{RESULT} = 'SUCCESS';
        for my $sensline (split "\n", $repdata)
        {
            my ($k, $v) = split /=/, $sensline;
            $repvalues{$k} = $v;
        }
    }
    else
    {
        print "Driver is not executable or does not exist\n";
        $repvalues{RESULT} = 'FAIL';
    }
    return \%repvalues;
}


1;
