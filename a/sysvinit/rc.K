#!/bin/sh

. /etc/rc.conf
. /etc/rubixlib

# Set the path.
PATH=/sbin:/bin:/usr/bin:/usr/sbin

# Set linefeed mode to avoid staircase effect.
stty onlcr

#get off the login prompt
printsep

# Shut down the wireless connection
if [ ! -f /var/run/daemons/wlan-config -a -x /usr/sbin/wlan-config -a -r /var/run/wlan-config ]; then
	stat_busy "shutting down wifi"
	/usr/sbin/wlan-config disconnect
	stat_done
fi

if [ "$PREVLEVEL" = "2" -o "$PREVLEVEL" = "3" -o "$PREVLEVEL" = "4" -o "$PREVLEVEL" = "5" ]; then
	# Shutdown daemons
	let i=${#DAEMONS[@]}
	while [[ i -ge 0 ]]; do
		if [[ `echo ${DAEMONS[$i]} | grep '^[^\!]' | wc -l` -eq 1 ]]; then
			/etc/rc.d/${DAEMONS[$i]#@} stop
		fi
		let i=i-1
	done
	# find any leftover daemons and shut them down
	if [ -d /var/run/daemons ]; then
		for daemon in `ls /var/run/daemons`; do
			/etc/rc.d/$daemon stop
		done
	fi
fi

if [ "$PREVLEVEL" != "N" ]; then
	stat_busy "Sending all processes the SIGHUP signal..."
	killall5 -1
	stat_done
	stat_busy "Waiting for processes to hang up"
	for loop in 0 1 2 3 4 5 ; do
		sleep 1
	done
	stat_done
	stat_busy "Sending all processes the SIGTERM signal..."
	killall5 -15
	stat_done
	stat_busy "Waiting for processes to terminate"
	for loop in 0 1 2 3 4 5 ; do
		sleep 1
	done
	stat_done
	stat_busy "Sending all processes the SIGKILL signal..."
	killall5 -9
	stat_done
	stat_busy "Waiting for processes to exit"
	for loop in 0 1 2 3 4 5 ; do
		sleep 1
	done
	stat_done
fi

if [ "$RUNLEVEL" = "1" -o "$RUNLEVEL" = "S" ]; then
	telinit -t 1 1
fi
