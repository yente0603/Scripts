#!/bin/bash
if [ "$EUID" -ne 0 ]; then
  echo "ERROR: Please run this script as superuser:"
  echo "  sudo $0 [COUNT]"
  exit 1
fi

if [[ "$PWD" != /media/$SUDO_USER/* ]]; then
  echo "Warning: Please put this script into your USB before running."
  echo "         Otherwise, the test result may be incorrect!"; echo
fi

if [ "$1" = "" ];  then
  echo "Use default parameter with 1G x 1 count"
  echo "    Usage: sudo $0 [COUNT]";echo 
fi

COUNT=${1:-1}
usb_test() {
  # sudo lshw -C system | grep "product" 
  
  echo "USB Speed Write Testing..."
  dd if=/dev/zero of=$PWD/temp bs=1G count=$COUNT conv=fdatasync
  sync && echo 1 > /proc/sys/vm/drop_caches # Clean cache & buffer
  echo "USB Speed Read Testing..."
  dd if=$PWD/temp of=/dev/zero bs=1G count=$COUNT iflag=direct 
  rm -f $PWD/temp
  echo "Test Done!"
}

usb_test $COUNT
