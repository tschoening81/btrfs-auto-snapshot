# BTRFS Automatic snapshot service for Linux

`btrfs-auto-snapshot` is a Bash script designed to bring as much of the functionality of the wonderful ZFS snapshot tool
`zfs-auto-snapshot` to BTRFS as possible. It's similarly designed to get executed by some external scheduler like `cron`
(e.g. using `/etc/cron.{daily,hourly,weekly}`) or `systemd-timer` and then automatically creates snapshots of the given
BTRFS filesystems based on user-given retention policies. Those are responsible for naming the created snapshots and to
define how many of those corresponding to some name should be kept. The important thing to note here is that those names
of snapshots need to correspond to how often the script gets triggered externally to be able to properly destroy snaps,
as it only calculates the number of snaps with some given name and doesn't maintain any state.
Snapshots are stored in a `.btrfs` directory at the root of the BTRFS filesystem being snapped and read-only by default.

# Usage

The following shows how to use the script with `systemd-timer` and a custom helper to maintain label names and a number
of snaps to keep per filesystem of interest.

```bash
1787100 4 -rwxrw-r-- 1 root root 1687 Dec 31 22:38 btrfs-auto-snap.sh
 296720 4 -rw-rw-r-- 1 root root  124 Nov 26 13:49 sch.tst.btrfs-auto-snap@.service
 311317 4 -rw-rw-r-- 1 root root  138 Nov 26 19:07 sch.tst.btrfs-auto-snap@daily.timer
 311323 4 -rw-rw-r-- 1 root root  141 Nov 26 19:07 sch.tst.btrfs-auto-snap@freqly.timer
 311329 4 -rw-rw-r-- 1 root root  138 Nov 26 19:08 sch.tst.btrfs-auto-snap@hourly.timer
 311335 4 -rw-rw-r-- 1 root root  139 Nov 26 19:08 sch.tst.btrfs-auto-snap@monthly.timer
 311341 4 -rw-rw-r-- 1 root root  133 Nov 26 19:08 sch.tst.btrfs-auto-snap@weekly.timer
 311347 4 -rw-rw-r-- 1 root root  140 Nov 26 19:08 sch.tst.btrfs-auto-snap@yearly.timer
```

```bash
#!/usr/bin/env bash

##
# Execute {@code btrfs-auto-snapshot} in different scheduling scenarios.
#
# @param[in] The scenario of interest, e.g. {@code freqly}, {@code hourly} etc.
#

set -o errexit
set -o errtrace
set -o functrace
set -o nounset
set -o pipefail
#set -o xtrace

declare -r  ARG_LABEL="${1:?No label given.}"
declare -r  APP_BIN='/opt/btrfs/auto-snap/app/btrfs-auto-snapshot'
declare -ra APP_EXEC=(
  "${APP_BIN}"
  "--label=${ARG_LABEL}"
  '--syslog'
  '--verbose'
)

exec::_freqly() {
  "${APP_EXEC[@]}" '--keep=4' '//'
}

exec::_hourly() {
  # 365 means ~14 days.
  "${APP_EXEC[@]}" '--keep=365' '//'
}

exec::_daily() {
  "${APP_EXEC[@]}" '--keep=90'  '/'
  "${APP_EXEC[@]}" '--keep=365' '/home'
  "${APP_EXEC[@]}" '--keep=365' '/home/foobar'
}

exec::_weekly() {
  "${APP_EXEC[@]}" '--keep=15'  '/'
  "${APP_EXEC[@]}" '--keep=52' '/home'
  "${APP_EXEC[@]}" '--keep=52' '/home/foobar'
}

exec::_monthly() {
  "${APP_EXEC[@]}" '--keep=3'  '/'
  "${APP_EXEC[@]}" '--keep=12' '/home'
  "${APP_EXEC[@]}" '--keep=12' '/home/foobar'
}

exec::_yearly() {
  "${APP_EXEC[@]}" '--keep=5' '/home'
  "${APP_EXEC[@]}" '--keep=5' '/home/foobar'
}

"exec::_${ARG_LABEL}"
```

```ini
[Unit]
Description=btrfs-auto-snap Timer: %I

[Timer]
OnCalendar=Mon..Sun *-*-* *:00/15:00
Persistent=true

[Install]
WantedBy=timers.target
```

```ini
[Unit]
Description=btrfs-auto-snap Executor: %I

[Service]
ExecStart='/opt/btrfs/auto-snap/systemd/btrfs-auto-snap.sh' '%i'
```

# Logging

```bash
sudo journalctl --identifier 'btrfs-auto-snap' -p 'err' -f -n 100
```

# Maintainer

* **Thorsten Schöning**
  * GitHub: http://github.com/tschoening81

# Author

* **Douglas J Hunley**
  * GitHub: http://github.com/hunleyd

# Copyright and license

Copyright 2014-2023 Doug Hunley <doug.hunley@gmail.com>

This program is free software; you can redistribute it and/or modify it under
the terms of the GNU General Public License as published by the Free Software
Foundation; either version 2 of the License, or (at your option) any later
version.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more
details.

You should have received a copy of the GNU General Public License along with
this program; if not, write to the Free Software Foundation, Inc., 59 Temple
Place, Suite 330, Boston, MA  02111-1307  USA
