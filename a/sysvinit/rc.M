#!/bin/sh
#
# /etc/rc.M
#

. /etc/rc.conf
. /etc/rubixlib

#give things a second to initialize
sleep 1

# Set linefeed mode to avoid staircase effect.
stty onlcr

# Tell the viewers what's going to happen.
printh1 "going multiuser"
printsep

# Update all the shared library links
if [ -x /sbin/ldconfig ]; then
	stat_bkgd "running ldconfig"
	/sbin/ldconfig &
fi

# Update the X font indexes
if [ -x /usr/bin/fc-cache ]; then
	stat_bkgd "runnnig fc-cache"
	/usr/bin/fc-cache &
fi

# Start daemons
for daemon in "${DAEMONS[@]}"; do
	if [ "$daemon" = "${daemon#!}" ]; then
		if [ "$daemon" = "${daemon#@}" ]; then
			/etc/rc.d/$daemon start
		else
			stat_bkgd "starting ${daemon:1}"
			(/etc/rc.d/${daemon:1} start) &>/dev/null &
		fi
	fi
done

if [ -x /etc/rc.local ]; then
	stat_info "running /etc/rc.local"
	/etc/rc.local
fi

printsep

# End of file
