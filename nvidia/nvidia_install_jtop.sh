#!/bin/bash
# https://github.com/rbonghi/jetson_stats

sudo apt update
sudo apt install -y python3-dev python3-pip build-essential python3-setuptools
sudo pip3 uninstall jetson-stats --break-system-packages -y
sudo pip3 install --break-system-packages --no-cache-dir -v -U jetson-stats 
sudo jtop --install-service