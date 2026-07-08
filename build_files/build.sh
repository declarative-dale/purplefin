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
chmod 0755 /usr/libexec/purplefin/install-ghostty-defaults
chmod 0755 /usr/libexec/purplefin/run-firstboot-rpm-ostree
if [[ -d /usr/libexec/purplefin/firstboot-rpm-ostree.d ]]; then
	find /usr/libexec/purplefin/firstboot-rpm-ostree.d -maxdepth 1 -type f -exec chmod 0755 {} +
fi

echo ":: Installing common Purplefin RPM overlays"
dnf5 -y install ghostty
dnf5 -y --setopt=install_weak_deps=False install espanso-wayland

if command -v espanso >/dev/null 2>&1 && command -v setcap >/dev/null 2>&1; then
	echo ":: Granting Espanso Wayland input capability"
	setcap "cap_dac_override+p" "$(command -v espanso)"
fi

echo ":: Enabling common Purplefin services"
systemctl enable flatpak-nuke-fedora.service
systemctl enable flatpak-preinstall.service
systemctl enable purplefin-brew-bundle.service

echo ":: Applying Purplefin build profile: ${profile}"
"${profile_script}"

if [[ -d /usr/libexec/purplefin/firstboot-rpm-ostree.d ]] && find /usr/libexec/purplefin/firstboot-rpm-ostree.d -maxdepth 1 -type f -perm /111 -print -quit | grep -q .; then
	echo ":: Enabling Purplefin rpm-ostree first-boot tasks"
	systemctl enable purplefin-firstboot-rpm-ostree.service
else
	echo ":: No Purplefin rpm-ostree first-boot tasks enabled for profile ${profile}"
fi

dnf5 clean all
rm -rf /run/dnf /var/cache/libdnf5 /var/cache/ldconfig/aux-cache /var/lib/authselect/backups /var/lib/dnf/repos /var/lib/dnf/system-repo.lock /var/log/dnf5.log
