#!/usr/bin/env bash
set -euo pipefail

profile="${1:-${BUILD_PROFILE:-generic-x86_64}}"
profile_script="/tmp/purplefin-build/profiles/${profile}.sh"

if [[ ! "${profile}" =~ ^[a-z0-9._-]+$ ]]; then
	echo "Invalid build profile: ${profile}" >&2
	exit 2
fi

if [[ ! -x "${profile_script}" ]]; then
	echo "Unknown build profile: ${profile}" >&2
	echo "Available profiles:" >&2
	find /tmp/purplefin-build/profiles -maxdepth 1 -type f -name '*.sh' -printf '  %f\n' | sed 's/\.sh$//' >&2
	exit 2
fi

install -d /usr/share/purplefin
printf '%s\n' "${profile}" > /usr/share/purplefin/build-profile

chmod 0755 /usr/libexec/purplefin/apply-brew-bundle

echo ":: Installing common Purplefin RPM overlays"
dnf5 -y --disable-repo=terra install 1password-cli
dnf5 -y --setopt=install_weak_deps=False install espanso-wayland

if command -v espanso >/dev/null 2>&1 && command -v setcap >/dev/null 2>&1; then
	echo ":: Granting Espanso Wayland input capability"
	setcap "cap_dac_override+p" "$(command -v espanso)"
fi

echo ":: Enabling common Purplefin services"
systemctl enable flatpak-nuke-fedora.service
systemctl enable flatpak-preinstall.service
systemctl enable purplefin-1password-desktop.service
systemctl enable purplefin-brew-bundle.service

echo ":: Applying Purplefin build profile: ${profile}"
"${profile_script}"

dnf5 clean all
rm -rf /run/dnf /var/cache/libdnf5 /var/cache/ldconfig/aux-cache /var/lib/authselect/backups /var/lib/dnf/repos /var/lib/dnf/system-repo.lock /var/log/dnf5.log
