#!/bin/sh
if [ -z $udev_root ]; then
	  . /etc/udev/udev.conf
fi

cd_num=0
dvd_num=0
optical_device=$1
if ! ls -l $udev_root | grep -q ^l.*$optical_device ; then
  cd $udev_root
  for i in `/bin/ls cdrom? 2>/dev/null`; do
    cd_num=$(($cd_num + 1))
  done
  for i in `/bin/ls dvd? 2>/dev/null`; do
    dvd_num=$(($dvd_num + 1))
  done
  if [ "$cd_num" = "0" ]; then
    ln -sf $optical_device cdrom
    ln -sf $optical_device cdrom0
  else
    ln -sf $optical_device cdrom${cd_num}
  fi
  if grep -iq dvd /proc/ide/$optical_device/model ; then
    if [ "$dvd_num" = "0" ]; then
      ln -sf $optical_device dvd 
      ln -sf $optical_device dvd0
    else
      ln -sf $optical_device dvd${dvd_num}
    fi
  fi
fi
