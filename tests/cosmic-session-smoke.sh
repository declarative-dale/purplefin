#!/usr/bin/env bash
set -euo pipefail

smoke_user="${COSMIC_SMOKE_USER:-cosmic-smoke}"
smoke_uid="$(id -u "${smoke_user}")"
session_found=0

for session_id in $(loginctl list-sessions --no-legend | awk -v user="${smoke_user}" '$3 == user { print $1 }'); do
	if [[ "$(loginctl show-session "${session_id}" --property=Type --value)" != wayland ]]; then
		continue
	fi
	session_service="$(loginctl show-session "${session_id}" --property=Service --value)"
	if [[ "${session_service}" != gdm-* ]]; then
		continue
	fi
	# COSMIC currently leaves logind's optional Desktop field empty. If a
	# desktop value is present, still require it to identify COSMIC.
	session_desktop="$(loginctl show-session "${session_id}" --property=Desktop --value)"
	if [[ -n "${session_desktop}" && "${session_desktop,,}" != cosmic ]]; then
		continue
	fi
	session_found=1
	break
done

if ((session_found == 0)); then
	echo "No GDM Wayland login session found for ${smoke_user}" >&2
	exit 1
fi

pgrep --uid "${smoke_uid}" --exact cosmic-comp >/dev/null
test -x /usr/bin/start-cosmic
test -x /usr/libexec/xdg-desktop-portal-cosmic
test -f /usr/share/wayland-sessions/cosmic.desktop
grep -qx 'DefaultSession=cosmic.desktop' /etc/gdm/custom.conf
test "$(readlink -f /etc/systemd/system/display-manager.service)" = /usr/lib/systemd/system/gdm.service

echo "COSMIC Wayland login is active for ${smoke_user}"
