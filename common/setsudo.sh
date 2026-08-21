#!/bin/bash

[[ $EUID -eq 0 ]] && { echo "Please run this script without sudo."; exit 1 }
sudo grep $USER /etc/sudoers | grep -cq NOPASSWD || sudo su -c 'echo ${SUDO_USER} ALL=\(ALL:ALL\) NOPASSWD\:ALL >> /etc/sudoers'
