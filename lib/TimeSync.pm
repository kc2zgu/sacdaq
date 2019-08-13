package TimeSync;

use strict;

sub _sysfs_get {
    my $path = shift;
    open my $fd, '<', $path or return undef;
    my $data = <$fd> or return undef;
    chomp $data;
    return $data;
}

sub checktime_rtc {
    main::logmsg("Checking RTC time status");

    opendir my $rtcdir, "/sys/class/rtc";
    for my $rtc (readdir $rtcdir)
    {
	next unless $rtc =~ /^rtc/;
        my $rtcname = _sysfs_get("/sys/class/rtc/$rtc/name");
        main::logmsg("Found RTC $rtcname at $rtc");
        my $rtcdate = _sysfs_get("/sys/class/rtc/$rtc/date");
        main::logmsg("RTC date: $rtcdate");
        if ($rtcdate =~ /^(\d{4})/)
        {
            main::logmsg("RTC year: $1");
            if ($1 > 2010)
            {
                return 1;
            }
        }
    }
    main::logmsg("No valid RTC found");
    return 0;
}

sub checktime_ntp {
    main::logmsg("Checking NTP time status");

    if (system('chronyc', 'waitsync', '1', '10') == 0)
    {
        main::logmsg("Synchronized");
        return 1;
    }
    main::logmsg("Not Synchronized");
    sleep 1;
    return 0;
}

sub timesync_wait {
    if (checktime_rtc())
    {
	main::logmsg("RTC valid, time is synchronized");
	return 1;
    }
    while (1)
    {
	if (checktime_ntp())
	{
	    main::logmsg("Synchronized to NTP");
	    return 1;
	}
    }
}

1;
