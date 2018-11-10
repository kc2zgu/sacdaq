package SensInstance;

use strict;

use YAML qw/LoadFile/;
use IPC::Run qw/run/;
use File::Slurp;
use UUID::Tiny ':std';
use FindBin;

my $logsub;

sub logmsg {
    my $msg = shift;
    if (ref $logsub)
    {
        $logsub->($msg);
    }
    else
    {
        print STDERR "[LOG] $msg\n";
    }
}

sub setlog {
    $logsub = shift;
}

sub new {
    my ($class, $conf) = @_;

    my $self = LoadFile($conf);

    return undef unless (defined $self->{driver} && defined $self->{name});

    $self->{args} = [] unless exists $self->{args};

    my $uuid;
    eval {$uuid = read_file("sensors.d/$self->{name}.uuid")};
    chomp $uuid;
    if (defined $uuid && is_uuid_string($uuid))
    {
        $self->{uuid} = $uuid;
    }
    else
    {
        logmsg "No UUID found, creating a new one";
        $uuid = create_uuid_as_string();
        $self->{uuid} = $uuid;
        write_file("sensors.d/$self->{name}.uuid", "$uuid\n");
    }
    logmsg "UUID: $self->{uuid}";

    bless $self, $class;
}

sub report {
    my ($self, $time, $datadir) = @_;

    my $drvpath = "$FindBin::Bin/drivers";
    my $libpath = "$FindBin::Bin/lib";
    my $driver = $self->{driver};
    my $logfile = "$datadir/logs/$driver.log";

    my $drvfile = "$drvpath/$driver.pl";
    my %repvalues = ('SENSOR-NAME' => $self->{name}, 'SENSOR-UUID' => $self->{uuid}, TIME => $time);

    logmsg "About to run $drvfile";
    if (-x $drvfile)
    {
        my $repdata;
        $ENV{PERL5LIB} = $libpath;
        run ["$drvfile", @{$self->{args}}, "log=$logfile"], \undef, \$repdata;
        $repvalues{RESULT} = 'SUCCESS';
        for my $sensline (split "\n", $repdata)
        {
            my ($k, $v) = split /=/, $sensline;
            $repvalues{$k} = $v;
        }
        $repvalues{RESULT} = 'FAIL' unless defined ($repvalues{VALID});
    }
    else
    {
        logmsg "Driver is not executable or does not exist";
        $repvalues{RESULT} = 'FAIL';
    }
    return \%repvalues;
}


1;
