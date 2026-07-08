#!/usr/bin/env bash
set -euo pipefail

profile_root="/tmp/purplefin-profile-files/dell-xps-9350-intel/system_files"

echo ":: Applying Dell XPS 9350 Intel hardware overlay"
cp -a "${profile_root}/." /
chmod 0755 /usr/libexec/purplefin/track-plymouth-initramfs

echo ":: Ensuring fingerprint stack is present"
dnf5 -y install fprintd libfprint

echo ":: Enabling fingerprint authentication through authselect"
authselect select local with-silent-lastlog with-mdns4 with-fingerprint --force

echo ":: Enabling target-host Plymouth/refind initramfs tracking"
systemctl enable purplefin-plymouth-initramfs.service
