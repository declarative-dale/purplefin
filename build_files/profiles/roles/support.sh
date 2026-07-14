#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/tmp/purplefin-build/profiles/lib/role-common.sh
source /tmp/purplefin-build/profiles/lib/role-common.sh

purplefin_apply_role_overlay support

echo ":: Installing support role applications"
dnf5 -y --setopt=install_weak_deps=False install espanso-wayland
if command -v espanso >/dev/null 2>&1 && command -v setcap >/dev/null 2>&1; then
	setcap "cap_dac_override+p" "$(command -v espanso)"
fi
systemctl --global enable espanso.service
