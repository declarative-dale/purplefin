#!/usr/bin/env bash
set -euo pipefail

profile_root="/tmp/purplefin-profile-files/dell-xps-9350-intel/system_files"

echo ":: Applying Dell XPS 9350 Intel hardware overlay"
cp -a "${profile_root}/." /
chmod 0755 /usr/libexec/purplefin/firstboot-rpm-ostree.d/10-1password-desktop-layer
chmod 0755 /usr/libexec/purplefin/firstboot-rpm-ostree.d/20-dell-ipu7-stable-kernel
chmod 0755 /usr/libexec/purplefin/dell-ipu7-activate
chmod 0755 /usr/libexec/purplefin/dell-ipu7-rebind-sensor
chmod 0755 /usr/libexec/purplefin/install-librepods
chmod 0755 /usr/libexec/purplefin/install-refind-theme

# shellcheck source=/usr/libexec/purplefin/lib/dell-ipu7.sh
source /usr/libexec/purplefin/lib/dell-ipu7.sh

kernel_repo_id="$(purplefin_dell_ipu7_kernel_repo_id)"
kernel_repo_file="/etc/yum.repos.d/purplefin-dell-ipu7-mainline-kernel.repo"
kernel_runtime_packages=(
	kernel
	kernel-core
	kernel-modules
	kernel-modules-core
	kernel-modules-extra
)
kernel_build_packages=(
	kernel-devel
)
intel_cvs_repo="https://github.com/intel/vision-drivers.git"
intel_cvs_ref="845d6f8bdf66ff1f455901da9de5e00a53a83dce"
camera_runtime_packages=(
	libcamera
	libcamera-ipa
	libcamera-tools
	pipewire-plugin-libcamera
)

write_ipu7_kernel_repo() {
	install -d -m 0755 "$(dirname "${kernel_repo_file}")"
	cat >"${kernel_repo_file}" <<EOF
[${kernel_repo_id}]
name=Purplefin Dell IPU7 pinned mainline kernel source
baseurl=$(purplefin_dell_ipu7_kernel_repo_baseurl)
type=rpm-md
skip_if_unavailable=False
gpgcheck=1
gpgkey=$(purplefin_dell_ipu7_kernel_repo_gpgkey)
repo_gpgcheck=0
enabled=1
enabled_metadata=1
priority=90
EOF
}

collect_ipu7_kernel_package_specs() {
	local evr="$1"
	local arch="$2"
	shift 2
	local repoquery_output specs
	local repoquery_format=$'%{name}\t%{evr}\t%{arch}\n'

	repoquery_output="$(
		dnf5 -q --refresh --disablerepo='*' --enablerepo="${kernel_repo_id}" repoquery --available --qf "${repoquery_format}" "$@" | sort -u
	)"
	specs="$(printf '%s\n' "${repoquery_output}" | purplefin_dell_ipu7_collect_package_specs_from_repoquery "${evr}" "${arch}" "$@")" || return 1
	printf '%s\n' "${specs}"
}

validate_ipu7_kernel_config_from_rpm() {
	local evr="$1"
	local arch="$2"
	local release tmpdir rpm_path config_path status

	release="$(purplefin_dell_ipu7_kernel_release_for_evr_arch "${evr}" "${arch}")"
	tmpdir="$(mktemp -d)"
	if ! dnf5 -q --disablerepo='*' --enablerepo="${kernel_repo_id}" download --destdir="${tmpdir}" "kernel-core-${evr}.${arch}"; then
		rm -rf "${tmpdir}"
		return 1
	fi

	rpm_path="$(find "${tmpdir}" -maxdepth 1 -type f -name "kernel-core-${evr}.${arch}.rpm" -print -quit)"
	[[ -n "${rpm_path}" ]] || {
		rm -rf "${tmpdir}"
		return 1
	}

	(
		cd "${tmpdir}"
		rpm2cpio "${rpm_path}" | cpio -idm --quiet "./usr/lib/modules/${release}/config" "./lib/modules/${release}/config" "./boot/config-${release}" >/dev/null 2>&1 || true
	)

	status=1
	for config_path in \
		"${tmpdir}/usr/lib/modules/${release}/config" \
		"${tmpdir}/lib/modules/${release}/config" \
		"${tmpdir}/boot/config-${release}"; do
		if [[ -f "${config_path}" ]]; then
			if purplefin_dell_ipu7_validate_kernel_config_file "${config_path}"; then
				status=0
			fi
			break
		fi
	done
	rm -rf "${tmpdir}"
	return "${status}"
}

remove_non_ipu7_runtime_kernels() {
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
		echo ":: Removing inherited non-IPU7 runtime kernels: ${remove_specs[*]}"
		dnf5 -y remove --no-autoremove "${remove_specs[@]}"
	fi
}

remove_inherited_v4l2loopback_kmods() {
	local packages=(
		kmod-v4l2loopback
		v4l2loopback
	)
	local installed=()
	local package

	for package in "${packages[@]}"; do
		if rpm -q "${package}" >/dev/null 2>&1; then
			installed+=("${package}")
		fi
	done

	if ((${#installed[@]} > 0)); then
		echo ":: Removing inherited prebuilt v4l2loopback kmods before Dell IPU7 kernel install"
		dnf5 -y remove --no-autoremove "${installed[@]}"
	fi
}

assert_ipu7_firmware_present() {
	local firmware_root suffix

	for firmware_root in /usr/lib/firmware/intel/ipu /lib/firmware/intel/ipu; do
		for suffix in '' .xz .zst; do
			if [[ -f "${firmware_root}/ipu7_fw.bin${suffix}" ]]; then
				echo ":: Found Dell IPU7 firmware ${firmware_root}/ipu7_fw.bin${suffix}"
				return 0
			fi
		done
	done

	echo "Dell IPU7 firmware ipu7_fw.bin, ipu7_fw.bin.xz, or ipu7_fw.bin.zst is missing" >&2
	exit 1
}

install_intel_cvs_module() {
	local target_release="$1"
	local kernel_devel_spec="$2"
	local target_evr target_arch source_root checkout actual_ref vermagic installed_module package spec
	local build_packages=(git gcc make "${kernel_devel_spec}")
	local temporary_build_packages=()
	local cleanup_packages=()

	target_evr="${target_release%.*}"
	target_arch="${target_release##*.}"

	for package in "${build_packages[@]}"; do
		if ! rpm -q "${package}" >/dev/null 2>&1; then
			temporary_build_packages+=("${package}")
		fi
	done

	echo ":: Installing Fedora libcamera runtime and temporary Intel CVS build dependencies"
	dnf5 -y install "${camera_runtime_packages[@]}"
	dnf5 -y install "${build_packages[@]}"

	source_root="$(mktemp -d /tmp/purplefin-intel-cvs.XXXXXX)"
	checkout="${source_root}/vision-drivers"
	git init -q "${checkout}"
	git -C "${checkout}" remote add origin "${intel_cvs_repo}"
	git -C "${checkout}" fetch --depth 1 origin "${intel_cvs_ref}"
	git -C "${checkout}" checkout --quiet --detach FETCH_HEAD
	actual_ref="$(git -C "${checkout}" rev-parse HEAD)"
	if [[ "${actual_ref}" != "${intel_cvs_ref}" ]]; then
		echo "Intel CVS checkout resolved to ${actual_ref}, expected ${intel_cvs_ref}" >&2
		exit 1
	fi

	echo ":: Building Intel CVS ${intel_cvs_ref} for ${target_release}"
	make -C "${checkout}" \
		KERNELRELEASE="${target_release}" \
		KERNEL_SRC="/usr/lib/modules/${target_release}/build"

	vermagic="$(modinfo -F vermagic "${checkout}/intel_cvs.ko")"
	if [[ "${vermagic%% *}" != "${target_release}" ]]; then
		echo "Intel CVS module vermagic ${vermagic} does not match ${target_release}" >&2
		exit 1
	fi
	if ! modinfo -F alias "${checkout}/intel_cvs.ko" | grep -qx 'acpi\*:INTC10DE:\*'; then
		echo "Intel CVS module does not advertise the Dell Lunar Lake INTC10DE device" >&2
		exit 1
	fi

	install -D -m 0644 "${checkout}/intel_cvs.ko" \
		"/usr/lib/modules/${target_release}/updates/purplefin/intel_cvs.ko"
	install -D -m 0644 "${checkout}/LICENSE.txt" \
		/usr/share/licenses/purplefin-intel-cvs/LICENSE.txt
	install -d -m 0755 /usr/share/purplefin/dell-ipu7
	cat >/usr/share/purplefin/dell-ipu7/intel-cvs.provenance <<EOF
source_repo=${intel_cvs_repo}
source_commit=${intel_cvs_ref}
kernel_release=${target_release}
EOF

	depmod -a "${target_release}"
	installed_module="$(modinfo -k "${target_release}" -n intel_cvs)"
	if [[ "${installed_module}" != "/lib/modules/${target_release}/updates/purplefin/intel_cvs.ko" &&
		"${installed_module}" != "/usr/lib/modules/${target_release}/updates/purplefin/intel_cvs.ko" ]]; then
		echo "modinfo resolved intel_cvs to unexpected path ${installed_module}" >&2
		exit 1
	fi

	rm -rf "${source_root}"
	for package in "${temporary_build_packages[@]}"; do
		if [[ "${package}" != "${kernel_devel_spec}" ]]; then
			cleanup_packages+=("${package}")
		fi
	done
	cleanup_packages+=("${kernel_devel_spec}")
	for spec in \
		"kernel-devel-matched-${target_evr}.${target_arch}" \
		"kernel-devel-matched-${target_evr}.noarch"; do
		if rpm -q "${spec}" >/dev/null 2>&1; then
			cleanup_packages+=("${spec}")
		fi
	done

	if ((${#cleanup_packages[@]} > 0)); then
		echo ":: Removing Intel CVS build-only kernel packages"
		dnf5 -y remove --no-autoremove "${cleanup_packages[@]}"
	fi
}

install_ipu7_kernel() {
	local target_arch selected_evr target_release
	local runtime_specs_output build_specs_output
	local kernel_evrs=()
	local runtime_specs=()
	local build_specs=()
	local evr_query_format=$'%{evr}\n'

	for command in dnf5 rpm2cpio cpio; do
		command -v "${command}" >/dev/null 2>&1 || {
			echo "${command} is required to install the Dell IPU7 kernel" >&2
			exit 1
		}
	done

	write_ipu7_kernel_repo
	mapfile -t kernel_evrs < <(
		dnf5 -q --refresh --disablerepo='*' --enablerepo="${kernel_repo_id}" repoquery --available --qf "${evr_query_format}" kernel-core | sort -u
	)
	selected_evr="$(printf '%s\n' "${kernel_evrs[@]}" | purplefin_dell_ipu7_select_kernel_evr)" || {
		echo "Pinned Dell IPU7 kernel $(purplefin_dell_ipu7_default_kernel_evr) is not available in ${kernel_repo_id}" >&2
		exit 1
	}
	target_arch="$(purplefin_dell_ipu7_uname_m)"
	target_release="$(purplefin_dell_ipu7_kernel_release_for_evr_arch "${selected_evr}" "${target_arch}")"

	runtime_specs_output="$(collect_ipu7_kernel_package_specs "${selected_evr}" "${target_arch}" "${kernel_runtime_packages[@]}")" || {
		echo "Missing runtime package for coherent Dell IPU7 kernel ${selected_evr} in ${kernel_repo_id}" >&2
		exit 1
	}
	build_specs_output="$(collect_ipu7_kernel_package_specs "${selected_evr}" "${target_arch}" "${kernel_build_packages[@]}")" || {
		echo "Missing exact kernel-devel for Dell IPU7 kernel ${selected_evr} in ${kernel_repo_id}" >&2
		exit 1
	}
	mapfile -t runtime_specs <<<"${runtime_specs_output}"
	mapfile -t build_specs <<<"${build_specs_output}"

	validate_ipu7_kernel_config_from_rpm "${selected_evr}" "${target_arch}" || {
		echo "Target kernel ${target_release} does not expose the required Dell IPU7 config flags" >&2
		exit 1
	}

	echo ":: Installing Dell IPU7 baked kernel ${selected_evr}"
	remove_inherited_v4l2loopback_kmods
	dnf5 -y --disablerepo='*' --enablerepo="${kernel_repo_id}" install "${runtime_specs[@]}"
	remove_non_ipu7_runtime_kernels "${selected_evr}" "${target_arch}"
	assert_ipu7_firmware_present

	test -d "/usr/lib/modules/${target_release}" || {
		echo "Dell IPU7 kernel modules directory /usr/lib/modules/${target_release} was not installed" >&2
		exit 1
	}
	test -f "/usr/lib/modules/${target_release}/initramfs.img" || {
		echo "Dell IPU7 kernel initramfs /usr/lib/modules/${target_release}/initramfs.img was not installed" >&2
		exit 1
	}
	printf '%s\n' "${build_specs[@]}" > /usr/share/purplefin/dell-ipu7/kernel-build-packages
	install_intel_cvs_module "${target_release}" "${build_specs[0]}"
}

install_ipu7_kernel

echo ":: Enabling Dell IPU7 CVS activation and OV02C10 reprobe"
systemctl enable purplefin-dell-ipu7-camera.service

echo ":: Installing Librepods from pinned GitHub Actions artifact"
/usr/libexec/purplefin/install-librepods

echo ":: Enabling Dell XPS 9350 Intel rEFInd theme installer"
systemctl enable purplefin-refind-theme.service

echo ":: Ensuring 1Password CLI is present"
dnf5 -y --disable-repo=terra install 1password-cli
rpm -q 1password-cli
command -v op >/dev/null

echo ":: Ensuring fingerprint stack is present"
dnf5 -y install fprintd libfprint

echo ":: Ensuring security key stack is present"
dnf5 -y install pam-u2f pamu2fcfg libfido2 opensc pcsc-lite yubikey-manager

echo ":: Enabling fingerprint and optional U2F authentication through authselect"
authselect select local with-silent-lastlog with-mdns4 with-fingerprint with-pam-u2f --force

echo ":: Enabling smart card/security key socket"
systemctl enable pcscd.socket
