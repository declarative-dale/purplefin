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
chmod 0755 /usr/libexec/purplefin/update-bitwarden-flatpak
if [[ -d /usr/libexec/purplefin/firstboot-rpm-ostree.d ]]; then
	find /usr/libexec/purplefin/firstboot-rpm-ostree.d -maxdepth 1 -type f -exec chmod 0755 {} +
fi

echo ":: Removing inherited Tailscale"
systemctl disable tailscaled.service >/dev/null 2>&1 || true
rm -f /etc/yum.repos.d/tailscale.repo
rm -f /usr/share/ublue-os/privileged-setup.hooks.d/10-tailscale.sh
rm -f /usr/share/fish/completions/tailscale.fish
if [[ -f /etc/dnf/repos.override.d/99-config_manager.repo ]]; then
	sed -i '/^\[tailscale-stable\]$/,+1d' /etc/dnf/repos.override.d/99-config_manager.repo
fi
if [[ -f /usr/share/ublue-os/motd/tips/10-tips.md ]]; then
	sed -i '/^Tailscale is included,/d' /usr/share/ublue-os/motd/tips/10-tips.md
fi
if rpm -q tailscale >/dev/null 2>&1; then
	dnf5 -y remove --no-autoremove tailscale
fi
rm -f /etc/default/tailscaled

if rpm -q tailscale >/dev/null 2>&1; then
	echo "Tailscale RPM is still installed" >&2
	exit 1
fi
for command in tailscale tailscaled; do
	if command -v "${command}" >/dev/null 2>&1; then
		echo "Inherited Tailscale command is still present: ${command}" >&2
		exit 1
	fi
done
for path in \
	/etc/systemd/system/multi-user.target.wants/tailscaled.service \
	/etc/yum.repos.d/tailscale.repo \
	/usr/lib/systemd/system/tailscaled.service \
	/usr/share/fish/completions/tailscale.fish \
	/usr/share/ublue-os/privileged-setup.hooks.d/10-tailscale.sh; do
	if [[ -e "${path}" || -L "${path}" ]]; then
		echo "Inherited Tailscale path is still present: ${path}" >&2
		exit 1
	fi
done
if grep -q '^\[tailscale-stable\]$' /etc/dnf/repos.override.d/99-config_manager.repo 2>/dev/null; then
	echo "Inherited Tailscale repository override is still present" >&2
	exit 1
fi
if grep -q '^Tailscale is included,' /usr/share/ublue-os/motd/tips/10-tips.md 2>/dev/null; then
	echo "Inherited Tailscale MOTD tip is still present" >&2
	exit 1
fi

echo ":: Installing common Purplefin RPM overlays"
dnf5 -y install ghostty
dnf5 -y --setopt=install_weak_deps=False install espanso-wayland
base_packages=(
	fuse
	fuse-libs
	nm-connection-editor
	nm-connection-editor-desktop
	wireguard-tools
)
dnf5 -y install "${base_packages[@]}"

for package in "${base_packages[@]}"; do
	rpm -q "${package}"
done
for command in nm-connection-editor wg; do
	command -v "${command}" >/dev/null
done
test -f /usr/share/applications/nm-connection-editor.desktop

bash /tmp/purplefin-build/install-bitwarden-cli-rpm.sh
rpm -q purplefin-bitwarden-cli
test "$(rpm -qf --qf '%{NAME}\n' /usr/bin/bw)" = "purplefin-bitwarden-cli"
command -v bw >/dev/null

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

if command -v espanso >/dev/null 2>&1 && command -v setcap >/dev/null 2>&1; then
	echo ":: Granting Espanso Wayland input capability"
	setcap "cap_dac_override+p" "$(command -v espanso)"
fi

echo ":: Enabling common Purplefin services"
systemctl enable flatpak-nuke-fedora.service
systemctl enable flatpak-preinstall.service
systemctl enable purplefin-brew-bundle.service
systemctl enable purplefin-bitwarden-flatpak-update.timer

echo ":: Applying Purplefin build profile: ${profile}"
"${profile_script}"

if [[ -d /usr/libexec/purplefin/firstboot-rpm-ostree.d ]] && find /usr/libexec/purplefin/firstboot-rpm-ostree.d -maxdepth 1 -type f -perm /111 -print -quit | grep -q .; then
	echo ":: Enabling Purplefin rpm-ostree first-boot tasks"
	systemctl enable purplefin-firstboot-rpm-ostree.service
else
	echo ":: No Purplefin rpm-ostree first-boot tasks enabled for profile ${profile}"
fi

if [[ -z "${PURPLEFIN_OSTREE_LINUX:-}" ]]; then
	echo 'PURPLEFIN_OSTREE_LINUX is required so the OCI kernel label matches the image payload' >&2
	exit 1
fi
mapfile -t installed_kernel_releases < <(rpm -q --qf '%{EVR}.%{ARCH}\n' kernel-core)
if ((${#installed_kernel_releases[@]} != 1)) || [[ "${installed_kernel_releases[0]}" != "${PURPLEFIN_OSTREE_LINUX}" ]]; then
	echo "Kernel payload does not match ostree.linux=${PURPLEFIN_OSTREE_LINUX}: ${installed_kernel_releases[*]:-none}" >&2
	exit 1
fi
while IFS= read -r -d '' modules_dir; do
	if [[ "$(basename "${modules_dir}")" != "${PURPLEFIN_OSTREE_LINUX}" ]]; then
		while IFS= read -r -d '' module_file; do
			if owner="$(rpm -qf --qf '%{NAME}' "${module_file}" 2>/dev/null)"; then
				echo "Refusing to prune ${modules_dir}; ${module_file} is still owned by ${owner}" >&2
				exit 1
			fi
		done < <(find "${modules_dir}" \( -type f -o -type l \) -print0)
		echo ":: Removing stale module tree ${modules_dir}"
		rm -rf "${modules_dir}"
	fi
done < <(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -print0)
test -f "/usr/lib/modules/${PURPLEFIN_OSTREE_LINUX}/vmlinuz"
test -f "/usr/lib/modules/${PURPLEFIN_OSTREE_LINUX}/initramfs.img"

# Package transactions can recreate completions owned by otherwise retained shells.
rm -f /usr/share/fish/completions/tailscale.fish
test ! -e /usr/share/fish/completions/tailscale.fish

dnf5 clean all
rm -f /boot/symvers-*.xz
rm -rf /run/dnf /var/cache/libdnf5 /var/cache/ldconfig/aux-cache /var/lib/authselect/backups /var/lib/dnf/repos /var/lib/dnf/system-repo.lock /var/lib/rpm-state /var/log/dnf5.log*
