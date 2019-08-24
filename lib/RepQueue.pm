package RepQueue;

use strict;

sub new {
    my $class = shift;

    my $self = {reports => []};
    bless $self, $class;
}

sub push {
    my ($self, $report) = @_;

    $report->{retry} = 0;
    push @{$self->{reports}}, $report;
}

sub reportstr {
    my $report = shift;

    my $str = "$report->{'SENSOR-UUID'}\@$report->{'TIME'}";
    if ($report->{VALID})
    {
	$str .= "=$report->{VALUE}";
    }
    else
    {
	$str .= ":(INVALID)";
    }
    $str .= " [$report->{retry}]" if $report->{retry};
    return $str;
}

sub flush {
    my $self = shift;

    my @remain;
    for my $rep(@{$self->{reports}})
    {
	my $repstr = reportstr($rep);
	eval {
	    main::logmsg("Saving $repstr");
	    $self->_write($rep);
	};
	if ($@)
	{
	    main::logmsg("Write $repstr failed: $@");
	    $rep->{retry}++;
	    if ($rep->{retry} > 200)
	    {
		main::logmsg("Too many failures, discarding");
	    }
	    else
	    {
		push @remain, $rep;
	    }
	}
    }
    $self->{reports} = \@remain;
}

sub _write {
    my ($self, $report) = @_;

    if (defined $self->{db})
    {
        my $sensordef = $self->{db}->resultset('Sensordef')->find_or_create({name => $report->{'SENSOR-NAME'},
									     uuid => $report->{'SENSOR-UUID'},
									     dimension => $report->{'DIMENSION'}},
									    {key => 'uuid_unique'});
        my $time = $report->{TIME};
        my $result = $report->{RESULT} eq 'SUCCESS' ? 1 : 0;
        my $exts = join ';', map {my ($k)=/^X-(.*)$/;"$k=$report->{$_}"} sort grep {/^X-/} keys %$report;
        my $dbreport = $sensordef->create_related(reports => {time => $time,
                                                              result => $result,
                                                              valid => $report->{VALID},
                                                              dimension => $report->{DIMENSION},
                                                              value => $report->{VALUE},
                                                              unit => $report->{UNIT},
                                                              driver => $report->{DRIVER},
                                                              faults => $report->{FAULTS} // 'none',
                                                              extensions => $exts});
    }
    else
    {
	main::logmsg("No database available, discarding");
    }
}

1;
