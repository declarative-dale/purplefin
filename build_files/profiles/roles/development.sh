#!/usr/bin/env bash
set -euo pipefail

# shellcheck source=/tmp/purplefin-build/profiles/lib/role-common.sh
source /tmp/purplefin-build/profiles/lib/role-common.sh

purplefin_apply_role_overlay development

echo ":: Installing development role terminal"
dnf5 -y install ghostty
chmod 0755 /usr/libexec/purplefin/install-ghostty-defaults
systemctl --global enable purplefin-ghostty-defaults.service

echo ":: Installing development role infrastructure tools"
infrastructure_packages=(
	ansible
	openbao
	opentofu
	packer
)
dnf5 -y install "${infrastructure_packages[@]}"

for package in "${infrastructure_packages[@]}"; do
	rpm -q "${package}"
done
for command in ansible bao packer tofu; do
	command -v "${command}" >/dev/null
done
