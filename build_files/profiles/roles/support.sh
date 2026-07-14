#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/tmp/purplefin-build/profiles/lib/authselect-features.sh
source /tmp/purplefin-build/profiles/lib/authselect-features.sh
# shellcheck source=/tmp/purplefin-build/profiles/lib/role-common.sh
source /tmp/purplefin-build/profiles/lib/role-common.sh

purplefin_apply_role_overlay support

echo ":: Installing support role applications"
dnf5 -y --setopt=install_weak_deps=False install espanso-wayland
if command -v espanso >/dev/null 2>&1 && command -v setcap >/dev/null 2>&1; then
	setcap "cap_dac_override+p" "$(command -v espanso)"
fi
systemctl --global enable espanso.service

echo ":: Installing support role security-key stack"
security_key_packages=(
	pam-u2f
	pamu2fcfg
	libfido2
	opensc
	pcsc-lite
	yubikey-manager
)
dnf5 -y install "${security_key_packages[@]}"
purplefin_authselect_request with-pam-u2f
systemctl enable pcscd.socket
