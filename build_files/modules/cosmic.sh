#!/usr/bin/env bash
set -euo pipefail

echo ":: Installing the Fedora COSMIC desktop groups"
# Bluefin already supplies the workstation, hardware, networking, printing,
# browser, and office groups pulled in by cosmic-desktop-environment. Install
# only the COSMIC desktop and its supplementary applications here.
dnf5 -y install @cosmic-desktop @cosmic-desktop-apps

rpm -q cosmic-session xdg-desktop-portal-cosmic
test -f /usr/share/wayland-sessions/cosmic.desktop
test -x /usr/bin/start-cosmic
test -x /usr/libexec/xdg-desktop-portal-cosmic
test -f /usr/share/xdg-desktop-portal/cosmic-portals.conf

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

# Installing cosmic-session also installs COSMIC Greeter, but this dual-desktop
# image intentionally retains Bluefin's GDM so GNOME remains a recovery option.
test "$(readlink -f /etc/systemd/system/display-manager.service)" = /usr/lib/systemd/system/gdm.service
