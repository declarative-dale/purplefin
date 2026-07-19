#!/usr/bin/env bash
set -euo pipefail

echo ":: Installing the Fedora COSMIC desktop environment"
dnf5 -y install @cosmic-desktop-environment

rpm -q cosmic-session
test -f /usr/share/wayland-sessions/cosmic.desktop

# Keep GNOME available for recovery, but make COSMIC the default GDM session.
gdm_config=/etc/gdm/custom.conf
install -d -m 0755 "$(dirname "${gdm_config}")"
if [[ -f "${gdm_config}" ]]; then
	if grep -q '^DefaultSession=' "${gdm_config}"; then
		sed -i 's/^DefaultSession=.*/DefaultSession=cosmic.desktop/' "${gdm_config}"
	elif grep -q '^\[daemon\]$' "${gdm_config}"; then
		sed -i '/^\[daemon\]$/a DefaultSession=cosmic.desktop' "${gdm_config}"
	else
		printf '\n[daemon]\nDefaultSession=cosmic.desktop\n' >>"${gdm_config}"
	fi
else
	printf '%s\n' '[daemon]' 'DefaultSession=cosmic.desktop' >"${gdm_config}"
fi

grep -qx 'DefaultSession=cosmic.desktop' "${gdm_config}"
