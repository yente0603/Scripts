#!/bin/bash
# Install Chromium above Jetpack 6.0, L4T 36.3, downgrade snap version.
# Ref: https://forums.developer.nvidia.com/t/chromium-other-browsers-not-working-after-flashing-or-updating-heres-why-and-quick-fix/338891

snap download snapd --revision=24724
sudo snap ack snapd_24724.assert
sudo snap install snapd_24724.snap
sudo snap refresh --hold snapd
sudo apt install chromium-browser -y