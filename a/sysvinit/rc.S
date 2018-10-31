#!/bin/sh
#
# /etc/rc.S:  System initialization script.
#
# Some written by Joshua Rubin, <joshua@rubix-os.org>
# Inspired by /etc/rc.d/rc.S in Slackware by Patrick Volkerding
# Also inspired by /etc/rc.sysinit in Arch by Judd Vinet
#

# anything more serious than KERN_WARNING goes to the console
/bin/dmesg -n 3

PATH=/sbin:/usr/sbin:/bin:/usr/bin

. /etc/rc.conf
. /etc/rubixlib

printsep
printh1 "Rubix Linux"
printh1 "http://www.rubixlinux.org"
printh1 "(C) 2006 Joshua Rubin"
printh1 "Distributed under the terms of the GNU General Public License (GPL)"
printsep

# Mount /proc right away
stat_busy "mounting /proc"
/sbin/mount proc /proc -n -t proc
stat_done

# If 'nohotplug' was given at boot, or hotplug has been turned off
# (is not executable), then shut off hotplugging in the kernel now.
# Turning off hotplug is *not* recommended, and will break some things.
if [ -w /proc/sys/kernel/hotplug ]; then
	if grep -w nohotplug /proc/cmdline 1> /dev/null 2> /dev/null ; then
		stat_busy "disabling hotplug"
		echo "/dev/null" > /proc/sys/kernel/hotplug
		stat_done
	elif [ ! -x /etc/rc.d/hotplug ]; then
		stat_busy "disabling hotplug"
		echo "/dev/null" > /proc/sys/kernel/hotplug
		stat_done
	fi
fi

# Mount sysfs next, if the kernel supports it
if [ -d /sys ]; then
	if cat /proc/filesystems | grep -w sysfs 1> /dev/null 2> /dev/null ; then
		if ! cat /proc/mounts | grep -w sysfs 1> /dev/null 2> /dev/null ; then
			stat_busy "mounting /sys"
			/sbin/mount sysfs /sys -n -t sysfs
			stat_done
		fi
	fi
fi

# Initialize udev to manage /dev entries for 2.6.x kernels
if [ -d /sys/block -a -r /proc/sys/kernel/hotplug -a -x /lib/udev/start_udev ]; then
	if ! grep -w nohotplug /proc/cmdline 1> /dev/null 2> /dev/null ; then
		stat_busy "starting udev"
		/lib/udev/start_udev > /dev/null 2>&1
		stat_done
	fi
fi

# Load the loop module and wait for it to initialize
if ! cat /proc/devices | grep -w loop 1> /dev/null 2> /dev/null ; then
	# If loop exists as a module, try to load it.
	if [ -r /lib/modules/$(cat /proc/sys/kernel/osrelease)/block/loop.*o.gz ]; then
		stat_busy "loading loop"
		modprobe loop > /dev/null 2>&1
		sleep 2
		stat_done
	fi
fi

# Initialize the Logical Volume Manager.
# This won't start unless we find /etc/lvmtab (LVM1) or
# /etc/lvm/backup/ (LVM2).  This is created by /sbin/vgscan, so to
# use LVM you must run /sbin/vgscan yourself the first time (and
# create some VGs and LVs).
if [ -r /etc/lvmtab -o -d /etc/lvm/backup ]; then
	# Check for device-mapper support.
	if ! cat /proc/devices | grep -w device-mapper 1> /dev/null 2> /dev/null ; then
		# If device-mapper exists as a module, try to load it.
		if [ -r /lib/modules/$(cat /proc/sys/kernel/osrelease)/kernel/drivers/md/dm-mod.ko.gz ]; then
			stat_busy "loading device-mapper"
			modprobe dm_mod > /dev/null 2>&1
			stat_done
		fi
	fi
	# Scan for new volume groups:
	/sbin/vgscan --ignorelockingfailure > /dev/null 2>&1
	if [ $? = 0 ]; then
		stat_busy "starting lvm"
		# This needs a moment to register.
		sleep 10
		# Make volume groups available to the kernel.
		# This should also make logical volumes available.
		/sbin/vgchange -ay --ignorelockingfailure > /dev/null 2>&1
		stat_done
	fi
fi

# Enable swapping
stat_busy "enabling swap"
/sbin/swapon -a > /dev/null 2>&1
stat_done

# Test to see if the root partition is read-only, like it ought to be.
READWRITE=no
if touch /fsrwtestfile 2>/dev/null; then
	rm -f /fsrwtestfile
	READWRITE=yes
fi

# See if a forced filesystem check was requested at shutdown:
if [ -r /etc/forcefsck ]; then
	FORCEFSCK="-f"
fi

if [ ! $READWRITE = yes ]; then
	RETVAL=0
	if [ ! -r /etc/fastboot ]; then
		stat_busy "checking root filesystem"
		/sbin/fsck $FORCEFSCK -T -C -a / > /dev/null 2>&1
		RETVAL=$?
		stat_done
	fi
	# An error code of 2 or higher will require a reboot.
	if [ $RETVAL -ge 2 ]; then
		# An error code equal to or greater than 4 means that some errors
		# could not be corrected.  This requires manual attention, so we
		# offer a chance to try to fix the problem in single-user mode
		if [ $RETVAL -ge 4 ]; then
			stat_err
			stat_err "***********************************************************"
			stat_err "*** An error occurred during the root filesystem check. ***"
			stat_err "*** You will now be given a chance to log into the      ***"
			stat_err "*** system in single-user mode to fix the problem.      ***"
			stat_err "***                                                     ***"
			stat_err "*** If you are using the ext2 filesystem, running       ***"
			stat_err "*** 'e2fsck -v -y <partition>' might help.              ***"
			stat_err "***********************************************************"
			stat_err
			stat_err "Once you exit the single-user shell, the system will reboot."
			stat_err
			PS1="(Repair filesystem) \#"; export PS1
			sulogin
		else # With an error code of 2 or 3, reboot the machine automatically
			stat_err
			stat_err "***********************************"
			stat_err "*** The filesystem was changed. ***"
			stat_err "*** The system will now reboot. ***"
			stat_err "***********************************"
			stat_err
		fi
		stat_busy "unmounting file systems"
		/sbin/umount -a -r
		/sbin/mount -n -o remount,ro /
		stat_done
		printsep
		printh1 "rebooting system"
		printsep
		sleep 2
		reboot -f
	fi
	# Remount the root filesystem in read-write mode
	stat_busy "remounting root file system"
	RETVAL=0
	/sbin/mount -w -n -o remount /
	RETVAL=$?
	stat_done
	if [ $RETVAL -gt 0 ] ; then
		stat_err
		stat_err "Attempt to remount root device as read-write failed!  This is going to"
		stat_err "cause serious problems."
		stat_err
		stat_err "Please press ENTER to continue, then reboot and start looking for the"
		stat_err "problem."
		read junk;
	fi
else
	stat_err
	stat_err "*** ERROR: Root partition has already been mounted read-write. Cannot check!"
	stat_err
	stat_err "For filesystem checking to work properly, your system must initially mount"
	stat_err "the root partition as read only. Please modify your kernel with 'rdev' so that"
	stat_err "it does this. If you're booting with GRUB, add to the kernel line:"
	stat_err
	stat_err "   ro"
	stat_err
	stat_err "in your /boot/grub/menu.lst"
	stat_err
	stat_err "If you boot from a kernel on a floppy disk, put it in the drive and type:"
	stat_err "   rdev -R /dev/fd0 1"
	stat_err
	stat_err "If you boot from a bootdisk, or with Loadlin, you can add the 'ro' flag."
	stat_err
	stat_err "This will fix the problem *AND* eliminate this annoying message. :^)"
	stat_err
	printsep
	printh1 "Press ENTER to continue."
	printsep
	read junk;
fi # Done checking root filesystem

# Any /etc/mtab that exists here is old, so we delete it to start over
/bin/rm -f /etc/mtab*

# Remounting the / partition will initialize the new /etc/mtab
/sbin/mount -w -o remount /

# Fix /etc/mtab to list sys and proc if they were not yet entered in
# /etc/mtab because / was still mounted read-only
if [ -d /proc/sys ]; then
	/sbin/mount -f proc /proc -t proc
fi

if [ -d /sys/bus ]; then
	/sbin/mount -f sysfs /sys -t sysfs
fi

if [ "$TIMEZONE" != "" ]; then
	/bin/ln -sf /usr/share/zoneinfo/$TIMEZONE /etc/localtime
fi

# Set the system time from the hardware clock using hwclock --hctosys.
if [ -x /sbin/hwclock ]; then
	# Check for a broken motherboard RTC clock (where ioports for rtc are
	# unknown) to prevent hwclock causing a hang
	if ! grep -q -w rtc /proc/ioports ; then
		CLOCK_OPT="--directisa"
	fi
	stat_busy "setting system time"
	if [ "$HARDWARECLOCK" = "UTC" ]; then
		/sbin/hwclock $CLOCK_OPT --utc --hctosys
	else
		/sbin/hwclock $CLOCK_OPT --localtime --hctosys
	fi
	stat_done
fi



# Configure ISA Plug-and-Play devices
if [ -r /etc/isapnp.conf ]; then
	if [ -x /sbin/isapnp ]; then
		/sbin/isapnp /etc/isapnp.conf
	fi
fi

### Update module dependencies ###
RELEASE=`uname -r`
# If /usr is mounted and we have 'find', we can try to take a shortcut:
if [ -x /usr/bin/find -a -e /lib/modules/$RELEASE/modules.dep -a /lib/modules/$RELEASE/modules.dep -nt /etc/modules.conf -a -r /proc/modules ]; then
	NEWMODS="`/usr/bin/find /lib/modules/$RELEASE -type f -newer /lib/modules/$RELEASE/modules.dep`"
	# Only rebuild dependencies if new module(s) are found:
	if [ ! "" = "$NEWMODS" ]; then
		stat_busy "running depmod"
		/sbin/depmod -a
		stat_done
	fi
else # we don't have find, or there is no existing modules.dep, or it is out of date.
	stat_busy "running depmod"
	/sbin/depmod -A
	stat_done
fi

# Load modules from the MODULES array defined in rc.conf
stat_busy "loading modules"
for mod in "${MODULES[@]}"; do
	if [[ `echo $mod | grep '^[^\!]' | wc -l` -eq 1 ]]; then
		/sbin/modprobe $mod
	fi
done
stat_done

# Configure runtime kernel parameters
if [ -x /sbin/sysctl -a -r /etc/sysctl.conf ]; then
	/sbin/sysctl -e -p /etc/sysctl.conf
fi

# Check all the non-root filesystems
if [ ! -r /etc/fastboot ]; then
	stat_busy "checking filesystems"
	/sbin/fsck $FORCEFSCK -C -R -T -A -a > /dev/null 2>&1
	stat_done
fi

# mount non-root file systems in fstab (but not NFS or SMB
# because TCP/IP is not yet configured, and not proc because
# that has already been mounted)
stat_busy "mounting filesystems"
/sbin/mount -a -t nonfs,nosmbfs,noproc
stat_done

stat_busy "initializing environment"

if [ ! -f /var/lib/hwclock/adjtime ]; then
	echo "0.0 0 0.0" > /var/lib/hwclock/adjtime
fi

# Remove leftover files
/bin/rm	-rf			\
	/var/log/daemon/*	\
	/var/run/utmp		\
	/var/run/*.pid		\
	/etc/nologin		\
	/etc/resolv.conf	\
	/var/run/lpd*		\
	/var/run/ppp*		\
	/etc/dhcpc/*.pid	\
	/etc/forcefsck		\
	/etc/fastboot		\
	/etc/shutdownpid	\
	/var/locks/*		\
	/var/run/*.pid		\
	/var/run/daemons/*	\
	/var/lock/*		\
	/var/spool/uucp/LCK..*	\
	/core			\
	/tmp/*			\
	/tmp/.*			\
	2> /dev/null

# Create /tmp/{.ICE-unix,.X11-unix} if they are not present
if [ ! -e /tmp/.ICE-unix ]; then
	mkdir -p /tmp/.ICE-unix
	chmod 1777 /tmp/.ICE-unix
fi
if [ ! -e /tmp/.X11-unix ]; then
	mkdir -p /tmp/.X11-unix
	chmod 1777 /tmp/.X11-unix
fi

# Attempt to umount and remove any leftover /initrd
if [ -d /initrd ]; then
	/sbin/umount /initrd 2> /dev/null
	rmdir /initrd 2> /dev/null
	blockdev --flushbufs /dev/ram0 2> /dev/null
fi

# Create a fresh utmp file
touch /var/run/utmp
chown root.utmp /var/run/utmp
chmod 664 /var/run/utmp

# Setup the /etc/motd to reflect the current kernel level
# THIS WIPES ANY CHANGES YOU MAKE TO /ETC/MOTD WITH EACH BOOT.
# COMMENT THIS OUT IF YOU WANT TO MAKE A CUSTOM VERSION.
echo "$(/bin/uname -sr)" > /etc/motd

# Carry an entropy pool between reboots to improve randomness.
if [ -f /etc/random-seed ]; then
	cat /etc/random-seed > /dev/urandom
fi

# Generate a new random-seed
# Use the pool size from /proc, or 512 bytes
if [ -r /proc/sys/kernel/random/poolsize ]; then
	dd if=/dev/urandom of=/etc/random-seed count=1 bs=$(cat /proc/sys/kernel/random/poolsize) 2> /dev/null
else
	dd if=/dev/urandom of=/etc/random-seed count=1 bs=512 2> /dev/null
fi
chmod 600 /etc/random-seed

# Screen blanks after 15 minutes idle time, and powers down in one hour
# if the kernel supports APM or ACPI power management:
/bin/setterm -blank 15 -powersave powerdown -powerdown 60

# Set the host name
if [ "$HOSTNAME" != "" ]; then
	/bin/hostname $HOSTNAME
	echo $HOSTNAME > /etc/HOSTNAME
else
	# fall back on this old default:
	/bin/hostname darkstar
	echo darkstar > /etc/HOSTNAME
fi

# Set the domain name
if [ "$DOMAINNAME" != "" ]; then
	/bin/domainname $DOMAINNAME
	echo $DOMAINNAME > /etc/defaultdomain
else
	# fall back on this old default:
	/bin/domainname example.net
	echo example.net > /etc/defaultdomain
fi

# Ensure basic filesystem permissions sanity.
chmod 755 / 2> /dev/null
chmod 1777 /tmp /var/tmp

if [ "$KEYMAP" != "" ]; then
	/bin/loadkeys -q $KEYMAP
fi

if [ "$CONSOLEFONT" != "" ]; then
	for i in `seq 1 12`; do
		if [ "$CONSOLEMAP" != "" ]; then
			/usr/bin/setfont -m $CONSOLEMAP $CONSOLEFONT -C /dev/vc/${i}
		else
			/usr/bin/setfont $CONSOLEFONT -C /dev/vc/${i};
		fi
	done
fi

for i in `seq 1 12`; do
	case "$NUMLOCK" in
		[Yy][Ee][Ss])
			setleds -D +num < /dev/vc/${i}
			;;
	esac
done

# Save the contents of 'dmesg'
/bin/dmesg -s 65536 > /var/log/dmesg

stat_done
printsep
