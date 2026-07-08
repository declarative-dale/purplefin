#!/usr/bin/env bash
set -euo pipefail

profile_root="/tmp/purplefin-profile-files/dell-xps-9350-intel/system_files"

echo ":: Applying Dell XPS 9350 Intel hardware overlay"
cp -a "${profile_root}/." /
chmod 0755 /usr/libexec/purplefin/track-plymouth-initramfs

echo ":: Ensuring fingerprint stack is present"
dnf5 -y install fprintd libfprint

echo ":: Ensuring security key stack is present"
dnf5 -y install pam-u2f pamu2fcfg libfido2 opensc pcsc-lite yubikey-manager

echo ":: Enabling fingerprint and optional U2F authentication through authselect"
authselect select local with-silent-lastlog with-mdns4 with-fingerprint with-pam-u2f --force

echo ":: Enabling smart card/security key socket"
systemctl enable pcscd.socket

echo ":: Enabling target-host Plymouth/refind initramfs tracking"
systemctl enable purplefin-plymouth-initramfs.service
