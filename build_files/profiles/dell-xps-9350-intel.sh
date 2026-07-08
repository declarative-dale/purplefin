#!/usr/bin/env bash
set -euo pipefail

profile_root="/tmp/purplefin-profile-files/dell-xps-9350-intel/system_files"

echo ":: Applying Dell XPS 9350 Intel hardware overlay"
cp -a "${profile_root}/." /
chmod 0755 /usr/libexec/purplefin/firstboot-rpm-ostree.d/10-1password-desktop-layer
chmod 0755 /usr/libexec/purplefin/install-refind-theme

echo ":: Enabling Dell XPS 9350 Intel rEFInd theme installer"
systemctl enable purplefin-refind-theme.service

echo ":: Ensuring 1Password CLI is present"
dnf5 -y --disable-repo=terra install 1password-cli
rpm -q 1password-cli
command -v op >/dev/null

echo ":: Ensuring fingerprint stack is present"
dnf5 -y install fprintd libfprint

echo ":: Ensuring security key stack is present"
dnf5 -y install pam-u2f pamu2fcfg libfido2 opensc pcsc-lite yubikey-manager

echo ":: Enabling fingerprint and optional U2F authentication through authselect"
authselect select local with-silent-lastlog with-mdns4 with-fingerprint with-pam-u2f --force

echo ":: Enabling smart card/security key socket"
systemctl enable pcscd.socket
