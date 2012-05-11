#!/usr/bin/perl -w

# dmesg on modern kernels prefixes each line with the number of seconds since boot.
# This script determines the boot time and turns the 'seconds' since boot to a (local) human time. 
# So instead of seeing
# [  649.701570] tun: Universal TUN/TAP device driver, 1.6
# you get
# 2012-05-10 22:33:57 [  649.701570] tun: Universal TUN/TAP device driver, 1.6

use strict;
use DateTime;
use 5.010;

sub get_dt_now {
    my $dt;
    for my $tz ('local', 'America/Toronto', 'EST5EDT') {
	eval { $dt = DateTime->now( time_zone => $tz ); };
	return $dt unless $@;
    }
    return DateTime->now(); # if no perferred time zone found.. default to UTC
}

sub get_dt_boot {
    if ( -e '/proc/uptime' ) {
	if ( open(my $uptime, '<', '/proc/uptime') ) {
	    my $line = <$uptime>;
	    my ($seconds_since_boot, $idle_seconds) = split(/\s+/, $line);
	    my $dt = get_dt_now();
	    $dt->add( seconds => -$seconds_since_boot );
	    close($uptime);
	    return ($dt, 0);
	}
    }
    # rely on `uptime` implies only 'minute' accuracy, no data for seconds. :(
    my $uptime_str = `uptime`;

    die "no /proc/uptime and uptime returned an unexpected format $uptime_str" unless $uptime_str =~
	/^
	    \s*
	    \d\d:\d\d:\d\d # now as reported by uptime.. ignore it
	    \s+up\s+
	    (?:
		(?:(?<n_days>\d+)\s+days,\s+)?(?<off_h>\d?\d):(?<off_m>\d\d)
	    |
		(?<n_min>\d+)\s+min,
	    )
	/x;

    my $dt = get_dt_now();
    $dt->add( days    => -$+{n_days} ) if $+{n_days};
    $dt->add( hours   => -$+{off_h } ) if $+{off_h};
    $dt->add( minutes => -$+{off_m } ) if $+{off_m};
    $dt->add( minutes => -$+{n_min } ) if $+{n_min};

    return ($dt, 'WARNING: boot time is only known to within a minute, so all all human legible times can be off by a minute' );
}

sub main {
    my ($dt_boot, $warning) = get_dt_boot();
    print "Booted at " . $dt_boot->ymd() . ' ' . $dt_boot->hms() . "\n";

    open(my $dmesg, '-|', 'dmesg') || die "Could not call dmesg: $!";
    while(<$dmesg>) {
	if ( /^\[\s*(\d+)\.\d+\s*\]/ ) {
	    my $dt = $dt_boot->clone()->add( seconds => $1 );
	    if ( $warning ) {
		printf("%s %02d:%02d %s", $dt->ymd, $dt->hour, $dt->min, $_);
	    } else {
		print $dt->ymd . ' ' . $dt->hms . ' ' . $_;
	    }
	} else {
	    print;
	}
    }
    print "TimeZone = " . $dt_boot->time_zone->name . "\n";
    print "$warning\n" if $warning;
}

main();
