#!/usr/bin/perl

use strict;

use DateTime;

use FindBin;
use lib "$FindBin::Bin/lib";

use SensDB;
use ApiClient;

my $dbfile = "logs/sensordata.sqlite";
my $db = SensDB->connect("dbi:SQLite:$dbfile");

my $api = ApiClient->new("http://eternium.local:3000/api/");

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
            print "Searching for new reports\n";
            $reports_rs = $def->search_related('reports', {time => {'>', $res->{last_datetime}}}, {order_by => {-asc => 'time'}});
        }
        else
        {
            print "Searching all reports\n";
            $reports_rs = $def->search_related('reports', {}, {order_by => {-asc => 'time'}});
        }
        my @reportlist;
        while (my $report = $reports_rs->next)
        {
            my $time = $report->time;
            print "Fetched report for $time\n";
            push @reportlist, $report;

            if (@reportlist >= $synclimit)
            {
                my $repcount = @reportlist;
                print "Sending $repcount reports\n";
                my $res = $api->sendreports($uuid, $def->name, @reportlist);
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
                @reportlist = ();
            }
        }
        if (@reportlist > 0)
        {
            my $repcount = @reportlist;
            print "Sending $repcount reports\n";
            my $res = $api->sendreports($uuid, $def->name, @reportlist);
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
