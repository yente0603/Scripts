#!/bin/bash

sudo apt update
sudo apt install -y python3-dev python3-pip build-essential
sudo pip3 uninstall jetson-stats
sudo pip3 install --no-cache-dir -v -U jetson-stats