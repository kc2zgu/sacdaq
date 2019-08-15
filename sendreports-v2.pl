#!/usr/bin/perl

use strict;

use DateTime;
use DateTime::Format::ISO8601;

use FindBin;
use lib "$FindBin::Bin/lib";

use SensDB;
use ApiClient;

my $dbfile = "logs/sensordata.sqlite";
my $db = SensDB->connect("dbi:SQLite:$dbfile");

my $apihost = "http://moclus-sacdaq.local:3000/api/";
if (exists $ENV{DAQ_API})
{
$apihost = $ENV{DAQ_API};
}

my $api = ApiClient->new($apihost);

my @sensordefs = $db->resultset('Sensordef')->all;

for my $def(@sensordefs)
{
    my $uuid = $def->uuid;
    print "found $uuid\n";

    my $res = $api->getstatus($uuid);
    my $needsync = 0;
    if ($res->{exists} == 0)
    {
        $needsync = 1;
    }
    else
    {
        my ($lastrep) = $def->search_related('reports', {},
                                             {order_by => {-desc=>'time'},
                                              rows => 1});
        if ($lastrep->time gt $res->{last_datetime})
        {
            print "New reports in local database\n";
            $needsync = 1;
        }
    }

    if ($needsync)
    {
        my $synclimit = 200;
        if ($res->{sync_limit})
        {
            $synclimit = $res->{sync_limit};
        }

        print "Syncing sensor reports\n";

        my $reports_rs;
        if (defined $res->{last_datetime})
        {
	    my $last_dt = DateTime::Format::ISO8601->parse_datetime($res->{last_datetime});
	    $last_dt = $db->storage->datetime_parser->format_datetime($last_dt);
            print "Searching for new reports from $last_dt\n";
            $reports_rs = $def->search_related('reports',
		{time => {'>', $last_dt}}, {order_by => {-asc => 'time'}, rows => 5000});
        }
        else
        {
            print "Searching all reports\n";
            $reports_rs = $def->search_related('reports', {}, {order_by => {-asc => 'time'}, rows => 5000});
        }
        my @reportlist;
        while (my $report = $reports_rs->next)
        {
            my $time = $report->time;
	    my $count = @reportlist;
            print "Fetched report for $time ($count)\n";
            push @reportlist, $report;
	}
	$reports_rs = undef;
	my $repcount = @reportlist;
	print "$repcount reports to sync\n";
	my @reportbatch;
	while (@reportlist > 0)
	{
	    push @reportbatch, shift @reportlist;
            if (@reportbatch >= $synclimit)
            {
                my $repcount = @reportbatch;
		my $starttime = $reportbatch[0]->time;
                print "Sending $repcount reports $starttime\n";
                my $res = $api->sendreports($uuid, $def->name, @reportbatch);
                if ($res->{status} eq 'success')
                {
                    if ($res->{inserted} != $repcount)
                    {
                        die "$res->{inserted} report of $repcount synced\n";
                    }
                }
                else
                {
                    die "Error submitting reports: $res->{error}\n";
                }
                @reportbatch = ();
            }
        }
        if (@reportbatch > 0)
        {
            my $repcount = @reportbatch;
            print "Sending $repcount reports\n";
            my $res = $api->sendreports($uuid, $def->name, @reportbatch);
            if ($res->{status} eq 'success')
            {
                if ($res->{inserted} != $repcount)
                {
                    die "$res->{inserted} report of $repcount synced\n";
                }
            }
            else
            {
                die "Error submitting reports: $res->{error}\n";
            }
        }
    }
}
