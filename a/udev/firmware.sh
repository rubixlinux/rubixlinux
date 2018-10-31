#!/bin/sh

# directory of the firmware files
FIRMWARE_DIR=/lib/firmware

# mountpoint of sysfs
SYSFS=$(sed -n 's/^.* \([^ ]*\) sysfs .*$/\1/p' /proc/mounts)

#
# What to do with this firmware hotplug event?
#
case "$ACTION" in

add)
    if [ ! -e $SYSFS/$DEVPATH/loading ]; then
        sleep 1
    fi

    if [ -f "$FIRMWARE_DIR/$FIRMWARE" ]; then
        echo 1 > $SYSFS/$DEVPATH/loading
        cp "$FIRMWARE_DIR/$FIRMWARE" $SYSFS/$DEVPATH/data
        echo 0 > $SYSFS/$DEVPATH/loading
    else
        echo -1 > $SYSFS/$DEVPATH/loading
    fi

    ;;

remove)
    ;;

*)
    echo "Firmware '$ACTION' event not supported"
    exit 1
    ;;

esac
