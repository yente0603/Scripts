sudo grep $USER /etc/sudoers | grep -cq NOPASSWD || sudo su -c 'echo $SUDO_USER ALL=\(ALL:ALL\) NOPASSWD\:ALL >> /etc/sudoers'
