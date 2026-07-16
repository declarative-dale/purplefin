#!/usr/bin/env bash
set -euo pipefail

profile_root="/tmp/purplefin-profile-files/dell-xps-9350-intel/system_files"
kernel_repo_id="purplefin-dell-mainline-kernel"
kernel_repo_file="/etc/yum.repos.d/${kernel_repo_id}.repo"
kernel_default_evr="7.1.2-355.vanilla.fc44"

# shellcheck source=/tmp/purplefin-build/profiles/lib/dell-xps-9350-common.sh
source /tmp/purplefin-build/profiles/lib/dell-xps-9350-common.sh

kernel_runtime_packages=(
	kernel
	kernel-core
	kernel-modules
	kernel-modules-core
	kernel-modules-extra
)

copy_profile_file() {
	local relative_path="$1"
	local source="${profile_root}/${relative_path}"
	local target="/${relative_path}"

	if [[ ! -e "${source}" ]]; then
		echo "Missing Dell profile source file: ${source}" >&2
		exit 1
	fi

	install -d -m 0755 "$(dirname "${target}")"
	cp -a "${source}" "${target}"
}

copy_profile_tree() {
	local relative_path="$1"
	local source="${profile_root}/${relative_path}"
	local target="/${relative_path}"

	if [[ ! -d "${source}" ]]; then
		echo "Missing Dell profile source directory: ${source}" >&2
		exit 1
	fi

	install -d -m 0755 "${target}"
	cp -a "${source}/." "${target}/"
}

write_mainline_kernel_repo() {
	install -d -m 0755 "$(dirname "${kernel_repo_file}")"
	cat >"${kernel_repo_file}" <<'EOF'
[purplefin-dell-mainline-kernel]
name=Purplefin Dell pinned mainline kernel source
baseurl=https://download.copr.fedorainfracloud.org/results/@kernel-vanilla/stable/fedora-$releasever-$basearch/
type=rpm-md
skip_if_unavailable=False
gpgcheck=1
gpgkey=https://download.copr.fedorainfracloud.org/results/@kernel-vanilla/stable/pubkey.gpg
repo_gpgcheck=0
enabled=1
enabled_metadata=1
priority=90
EOF
}

kernel_evr_supported() {
	local evr="${1#0:}"

	[[ "${evr}" =~ ^7[.]1[.][0-9]+- ]] || return 1
	[[ "${evr}" != *".rc"* && "${evr}" != *"-0.rc"* ]]
}

select_kernel_evr() {
	local requested_evr="${PURPLEFIN_DELL_MAINLINE_KERNEL_EVR:-}"
	local allow_unpinned="${PURPLEFIN_DELL_MAINLINE_KERNEL_ALLOW_UNPINNED:-0}"
	local evr selected_evr
	local available=()

	while IFS= read -r evr; do
		[[ -n "${evr}" ]] || continue
		available+=("${evr#0:}")
	done

	if [[ -n "${requested_evr}" ]]; then
		requested_evr="${requested_evr#0:}"
		kernel_evr_supported "${requested_evr}" || return 1
		for evr in "${available[@]}"; do
			if [[ "${evr}" == "${requested_evr}" ]]; then
				printf '%s\n' "${evr}"
				return 0
			fi
		done
		return 1
	fi

	if [[ "${allow_unpinned}" == "1" ]]; then
		selected_evr="$(
			for evr in "${available[@]}"; do
				if kernel_evr_supported "${evr}"; then
					printf '%s\n' "${evr}"
				fi
			done | sort -V | tail -n 1
		)"
		[[ -n "${selected_evr}" ]] || return 1
		printf '%s\n' "${selected_evr}"
		return 0
	fi

	for evr in "${available[@]}"; do
		if [[ "${evr}" == "${kernel_default_evr}" ]]; then
			printf '%s\n' "${evr}"
			return 0
		fi
	done
	return 1
}

collect_kernel_package_specs() {
	local evr="$1"
	local arch="$2"
	shift 2
	local package repoquery_output spec
	local specs=()
	local repoquery_format=$'%{name}\t%{evr}\t%{arch}\n'

	repoquery_output="$(
		dnf5 -q --refresh --disablerepo='*' --enablerepo="${kernel_repo_id}" repoquery --available --qf "${repoquery_format}" "$@" | sort -u
	)"

	for package in "$@"; do
		spec="$(
			awk -F $'\t' -v package="${package}" -v evr="${evr#0:}" -v arch="${arch}" '
				$1 == package && $2 == evr && ($3 == arch || $3 == "noarch") {
					print $1 "-" $2 "." $3
					found = 1
					exit
				}
				END {
					if (!found) {
						exit 1
					}
				}
			' <<<"${repoquery_output}"
		)" || return 1
		specs+=("${spec}")
	done

	printf '%s\n' "${specs[@]}"
}

remove_non_target_runtime_kernels() {
	local target_evr="$1"
	local target_arch="$2"
	local repoquery_output package evr arch spec
	local repoquery_format=$'%{name}\t%{evr}\t%{arch}\n'
	local remove_specs=()

	repoquery_output="$(dnf5 -q repoquery --installed --qf "${repoquery_format}" "${kernel_runtime_packages[@]}" | sort -u)"
	while IFS=$'\t' read -r package evr arch; do
		[[ -n "${package}" ]] || continue
		if [[ "${evr}" != "${target_evr#0:}" || "${arch}" != "${target_arch}" ]]; then
			spec="${package}-${evr}.${arch}"
			remove_specs+=("${spec}")
		fi
	done <<<"${repoquery_output}"

	if ((${#remove_specs[@]} > 0)); then
		echo ":: Removing inherited non-target runtime kernels: ${remove_specs[*]}"
		dnf5 -y remove --no-autoremove "${remove_specs[@]}"
	fi
}

remove_inherited_v4l2loopback_kmods() {
	local packages=(
		kmod-v4l2loopback
		kmod-zfs
		v4l2loopback
		zfs
	)
	local installed=()
	local package

	for package in "${packages[@]}"; do
		if rpm -q "${package}" >/dev/null 2>&1; then
			installed+=("${package}")
		fi
	done

	if ((${#installed[@]} > 0)); then
		echo ":: Removing inherited kernel add-ons without modules for the mainline kernel"
		dnf5 -y remove --no-autoremove "${installed[@]}"
	fi
}

install_mainline_7_1_kernel() {
	local target_arch selected_evr target_release
	local kernel_evrs=()
	local runtime_specs_output
	local runtime_specs=()
	local evr_query_format=$'%{evr}\n'

	for command in dnf5 rpm awk; do
		command -v "${command}" >/dev/null 2>&1 || {
			echo "${command} is required to install the Dell mainline kernel" >&2
			exit 1
		}
	done

	write_mainline_kernel_repo
	mapfile -t kernel_evrs < <(
		dnf5 -q --refresh --disablerepo='*' --enablerepo="${kernel_repo_id}" repoquery --available --qf "${evr_query_format}" kernel-core | sort -u
	)
	selected_evr="$(printf '%s\n' "${kernel_evrs[@]}" | select_kernel_evr)" || {
		echo "Pinned Dell mainline kernel ${kernel_default_evr} is not available in ${kernel_repo_id}" >&2
		exit 1
	}
	target_arch="$(uname -m)"
	target_release="${selected_evr}.${target_arch}"

	runtime_specs_output="$(collect_kernel_package_specs "${selected_evr}" "${target_arch}" "${kernel_runtime_packages[@]}")" || {
		echo "Missing runtime package for coherent Dell mainline kernel ${selected_evr} in ${kernel_repo_id}" >&2
		exit 1
	}
	mapfile -t runtime_specs <<<"${runtime_specs_output}"

	echo ":: Installing Dell no-camera mainline kernel ${selected_evr}"
	remove_inherited_v4l2loopback_kmods
	dnf5 -y --disablerepo='*' --enablerepo="${kernel_repo_id}" install "${runtime_specs[@]}"
	remove_non_target_runtime_kernels "${selected_evr}" "${target_arch}"
	rm -f "${kernel_repo_file}"

	test -d "/usr/lib/modules/${target_release}" || {
		echo "Dell mainline kernel modules directory /usr/lib/modules/${target_release} was not installed" >&2
		exit 1
	}
	test -f "/usr/lib/modules/${target_release}/initramfs.img" || {
		echo "Dell mainline kernel initramfs /usr/lib/modules/${target_release}/initramfs.img was not installed" >&2
		exit 1
	}
}

echo ":: Applying Dell XPS 9350 Intel no-camera test overlay"
copy_profile_file "etc/pam.d/polkit-1"
copy_profile_file "etc/pam.d/purplefin-dell-lid-auth"
copy_profile_file "etc/pam.d/purplefin-dell-password-auth"
copy_profile_file "etc/pam.d/sudo"
copy_profile_file "usr/libexec/purplefin/install-refind-theme"
copy_profile_file "usr/libexec/purplefin/dell-lid-is-open"
copy_profile_file "usr/lib/systemd/system/purplefin-refind-theme.service"
copy_profile_tree "usr/share/purplefin/refind"
copy_profile_file "usr/lib/purplefin/dell-xps-9350-battery.conf"
copy_profile_file "usr/lib/udev/hwdb.d/61-purplefin-dell-xps-9350-battery.hwdb"
copy_profile_file "usr/lib/tuned/profiles/purplefin-dell-xps-9350-performance/tuned.conf"
copy_profile_file "usr/lib/systemd/system/purplefin-dell-xps-9350-battery.service"
copy_profile_file "usr/libexec/purplefin/configure-dell-xps-9350-battery"
copy_profile_file "usr/lib/systemd/user/purplefin-dell-xps-9350-panel.service"
copy_profile_file "usr/libexec/purplefin/dell-xps-9350-panel-policy"
copy_profile_file "usr/share/purplefin/dell-xps-9350-panel.conf"
copy_profile_file "usr/share/glib-2.0/schemas/zz9-purplefin-dell-xps-9350.gschema.override"
copy_profile_file "etc/systemd/user/graphical-session.target.wants/purplefin-dell-xps-9350-panel.service"

chmod 0755 /usr/libexec/purplefin/install-refind-theme

install_mainline_7_1_kernel

purplefin_configure_dell_xps_9350_common

echo ":: Enabling Dell XPS 9350 Intel rEFInd theme installer"
systemctl enable purplefin-refind-theme.service
