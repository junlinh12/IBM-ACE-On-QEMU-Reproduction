#!/usr/bin/env bash
# IBM-ACE-On-QEMU-Reproduction: sanitize one evidence file for publication (standard input -> standard output).
#
# The review copies of the gate logs are already masked by the logging harness (user name, host name, home path).
# This second step removes time-zone information and the apt history's details:
#   - the host's local UTC offset, its compact form, its zone abbreviation, and its zone name, all read at run time,
#     so that this script itself contains none of them; timestamps written with the local offset become <local time>
#   - timedatectl-style fields (Local time, Time zone, RTC) and apt history fields (Start-Date, End-Date, Requested-By),
#     also where another command quotes them after a prefix such as file:line:
#   - with --pre-utc: ls-style times (for logs written before the harness printed UTC, gates G00-G07)
#   - with --ports FILE: the host's listening TCP ports, given one per line in a private FILE (never in this script):
#     the number-only output lines of an "ss -ltnH" pipeline, and listed ports in the sentences that name them
# On a host whose local time is UTC there is no offset to remove, and the offset rules are skipped.
#
# Usage: scripts/sanitize_evidence.sh [--pre-utc] [--ports FILE] < input > output
set -euo pipefail

PRE_UTC=0
PORTS_FILE=""
while [ $# -gt 0 ]; do
    case "$1" in
        --pre-utc) PRE_UTC=1 ;;
        --ports) PORTS_FILE="$2"; shift ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

LOCAL_OFFSET="$(env -u TZ date +%:z)"
LOCAL_OFFSET_COMPACT="$(env -u TZ date +%z)"
LOCAL_ZONE="$(env -u TZ date +%Z)"
LOCAL_TZNAME="$(timedatectl show -p Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || true)"
export PRE_UTC PORTS_FILE LOCAL_OFFSET LOCAL_OFFSET_COMPACT LOCAL_ZONE LOCAL_TZNAME

exec perl -pe '
    BEGIN {
        $utc  = ($ENV{LOCAL_OFFSET} eq "+00:00");
        $zone = $ENV{LOCAL_ZONE};
        $name = $ENV{LOCAL_TZNAME};
        $name = "" if $name eq "UTC" || $name eq "Etc/UTC";
        $ports = "";
        if (length $ENV{PORTS_FILE}) {
            open(my $fh, "<", $ENV{PORTS_FILE}) or die "cannot read the ports file\n";
            my @p = grep { /^\d+$/ } map { s/\s+//gr } <$fh>;
            die "the ports file lists no port\n" unless @p;
            $ports = join "|", @p;
        }
        $in_ss = 0;
    }
    unless ($utc) {
        s/\d{4}-\d\d-\d\d[T ]\d\d:\d\d:\d\d\Q$ENV{LOCAL_OFFSET}\E/<local time>/g;
        s/\w{3} \w{3} +\d{1,2} \d\d:\d\d:\d\d \d{4} \Q$ENV{LOCAL_OFFSET_COMPACT}\E/<local time>/g;
        s/\w{3} \w{3} +\d{1,2} \d\d:\d\d:\d\d \Q$zone\E \d{4}/<local time>/g if length $zone;
        s/\Q$ENV{LOCAL_OFFSET}\E/<local offset>/g;
        s/\Q$ENV{LOCAL_OFFSET_COMPACT}\E/<local offset>/g;
        s/\b\Q$zone\E\b/<local zone>/g if length $zone;
        s/\Q$name\E/<local zone>/g if length $name;
    }
    s/(Local time|Time zone|RTC time|RTC in local TZ):.*/$1: <removed>/;
    s/(Start-Date|End-Date):.*/$1: <removed>/;
    s/Requested-By:.*/Requested-By: <removed>/;
    s/ [A-Z][a-z]{2} +\d{1,2} \d\d:\d\d / <local time> /g if $ENV{PRE_UTC};
    if (length $ports) {
        if (/^\$ ss -ltnH$/) { $in_ss = 1; }
        elsif ($in_ss && /^\$ /) { }
        elsif ($in_ss && /^\d+$/) { $_ = "<port>\n"; }
        else { $in_ss = 0; }
        s/\b(?:$ports)\b/<port>/g if /Listening TCP ports|already in use|listens on|for example/;
    }
'
