#!/usr/bin/perl

use strict;

use DateTime;
use HTTP::Tiny;
use JSON;

use FindBin;
use lib "$FindBin::Bin/lib";

use SensDB;

my $dbfile = "logs/sensordata.sqlite";
my $db = SensDB->connect("dbi:SQLite:$dbfile");

my $synchost = 'http://bajor.local/cgi-bin/repsync.pl';
my $http = HTTP::Tiny->new;
my $json = JSON->new;

my @sensordefs = $db->resultset('Sensordef')->all;

for my $def(@sensordefs)
{
    my $uuid = $def->uuid;
    print "found $uuid\n";

    my $resp = $http->get("$synchost?action=checkreports&sensoruuid=$uuid");
    if ($resp->{success})
    {
        my $jsondata = $json->decode($resp->{content});
        if ($jsondata->{uuid} eq $uuid)
        {
            print "$jsondata->{records} on server, last $jsondata->{last_datetime}\n";
            if ($jsondata->{records} == 0)
            {
                print "syncing all reports\n";
                my $jsonreq = {uuid => $def->uuid, name => $def->name, reports => []};
                my $reports = $def->search_related('reports', {}, {order_by => {-asc => 'time'}});
                while (my $report = $reports->next)
                {
                    push @{$jsonreq->{reports}}, 
                      {time => $report->time,
                       result => $report->result,
                       valid => $report->valid,
                       dimension => $report->dimension,
                       value => $report->value,
                       unit => $report->unit,
                       driver => $report->driver,
                       faults => $report->faults,
                       extensions => $report->{extensions}};
                    
                }
                $resp = $http->post("$synchost?action=syncreports", {content => $json->pretty->encode($jsonreq)});
                if ($resp->{success})
                {
                    $jsondata = decode_json($resp->{content});
                    print "$jsondata->{records} reports synced\n";
                }
                else
                {
                    print "sync failed\n";
                }
            }
            else
            {
                my $jsonreq = {uuid => $def->uuid, name => $def->name, reports => []};
                my $reports = $def->search_related('reports', {time => {'>', $jsondata->{last_datetime}}}, {order_by => {-asc => 'time'}});
                while (my $report = $reports->next)
                {
                    push @{$jsonreq->{reports}}, 
                      {time => $report->time,
                       result => $report->result,
                       valid => $report->valid,
                       dimension => $report->dimension,
                       value => $report->value,
                       unit => $report->unit,
                       driver => $report->driver,
                       faults => $report->faults,
                       extensions => $report->{extensions}};
                    #print "new report, time ", $report->time, "\n";
                }
                my $count = @{$jsonreq->{reports}};
                if ($count > 0)
                {
                    print "Sending $count new reports\n";
                    $resp = $http->post("$synchost?action=syncreports", {content => $json->pretty->encode($jsonreq)});
                    if ($resp->{success})
                    {
                        $jsondata = decode_json($resp->{content});
                        print "$jsondata->{records} reports synced\n";
                    }
                    else
                    {
                        print "sync failed\n";
                    }
                }
                else
                {
                    print "No new data\n";
                }
            }
        }
    }
}
