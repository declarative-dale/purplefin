#!/usr/bin/env bash
# Shared helpers for Dell IPU7 first-boot setup.

purplefin_dell_ipu7_log() {
	if declare -F purplefin_firstboot_log >/dev/null 2>&1; then
		purplefin_firstboot_log "$@"
	else
		printf 'purplefin-dell-ipu7: %s\n' "$*" >&2
	fi
}

purplefin_dell_ipu7_default_kernel_evr() {
	printf '%s\n' "${PURPLEFIN_DELL_IPU7_DEFAULT_KERNEL_EVR:-7.1.2-355.vanilla.fc44}"
}

purplefin_dell_ipu7_minimum_kernel_version() {
	printf '%s\n' "${PURPLEFIN_DELL_IPU7_MINIMUM_KERNEL_VERSION:-7.1.2}"
}

purplefin_dell_ipu7_in_tree_cvs_version() {
	printf '%s\n' "${PURPLEFIN_DELL_IPU7_IN_TREE_CVS_VERSION:-7.2.0}"
}

purplefin_dell_ipu7_kernel_version_from_evr() {
	local evr="${1#0:}"

	printf '%s\n' "${evr%%-*}"
}

purplefin_dell_ipu7_version_at_least() {
	local candidate="$1"
	local minimum="$2"
	local newest

	[[ "${candidate}" =~ ^[0-9]+([.][0-9]+)*$ ]] || return 1
	[[ "${minimum}" =~ ^[0-9]+([.][0-9]+)*$ ]] || return 1
	newest="$(printf '%s\n' "${minimum}" "${candidate}" | sort -V | tail -n 1)"
	[[ "${newest}" == "${candidate}" ]]
}

purplefin_dell_ipu7_kernel_denylist_file() {
	printf '%s\n' "${PURPLEFIN_DELL_IPU7_KERNEL_DENYLIST:-/usr/share/purplefin/dell-ipu7/kernel-evr.denylist}"
}

purplefin_dell_ipu7_kernel_supported() {
	local release="${1:-}"
	local lower
	local version

	[[ -n "${release}" ]] || return 1
	lower="${release,,}"
	[[ "${lower}" != *rc* ]] || return 1

	version="$(purplefin_dell_ipu7_kernel_version_from_evr "${release}")"
	purplefin_dell_ipu7_version_at_least "${version}" "$(purplefin_dell_ipu7_minimum_kernel_version)"
}

purplefin_dell_ipu7_kernel_uses_in_tree_cvs() {
	local version

	version="$(purplefin_dell_ipu7_kernel_version_from_evr "$1")"
	purplefin_dell_ipu7_version_at_least "${version}" "$(purplefin_dell_ipu7_in_tree_cvs_version)"
}

purplefin_dell_ipu7_keep_inherited_kernel() {
	local inherited_evr="$1"

	[[ -z "${PURPLEFIN_DELL_IPU7_KERNEL_EVR:-}" ]] || return 1
	[[ "${PURPLEFIN_DELL_IPU7_KERNEL_ALLOW_UNPINNED:-0}" != "1" ]] || return 1
	purplefin_dell_ipu7_kernel_supported "${inherited_evr}" || return 1
	! purplefin_dell_ipu7_kernel_evr_denied "${inherited_evr#0:}"
}

purplefin_dell_ipu7_kernel_evr_denied() {
	local evr="$1"
	local denylist

	denylist="$(purplefin_dell_ipu7_kernel_denylist_file)"
	[[ -f "${denylist}" ]] || return 1

	awk -v evr="${evr}" '
		{
			sub(/[[:space:]]*#.*/, "")
			gsub(/^[[:space:]]+|[[:space:]]+$/, "")
		}
		$0 == evr { found = 1 }
		END { exit found ? 0 : 1 }
	' "${denylist}"
}

purplefin_dell_ipu7_kernel_release_for_evr_arch() {
	local evr="$1"
	local arch="$2"

	printf '%s.%s\n' "${evr#0:}" "${arch}"
}

purplefin_dell_ipu7_select_kernel_evr() {
	local line lower
	local supported_71=()
	local requested_evr="${PURPLEFIN_DELL_IPU7_KERNEL_EVR:-}"
	local default_evr

	while IFS= read -r line; do
		[[ -n "${line}" ]] || continue
		lower="${line,,}"
		[[ "${lower}" != *rc* ]] || continue

		if [[ "${line}" =~ (^|[^0-9])7\.1\.[0-9]+([^0-9]|$) ]]; then
			if ! purplefin_dell_ipu7_kernel_evr_denied "${line#0:}"; then
				supported_71+=("${line#0:}")
			fi
		fi
	done

	if [[ -n "${requested_evr}" ]]; then
		if ! purplefin_dell_ipu7_kernel_supported "${requested_evr}" || purplefin_dell_ipu7_kernel_evr_denied "${requested_evr#0:}"; then
			return 1
		fi

		for line in "${supported_71[@]}"; do
			if [[ "${line}" == "${requested_evr#0:}" ]]; then
				printf '%s\n' "${line}"
				return 0
			fi
		done
		return 1
	fi

	default_evr="$(purplefin_dell_ipu7_default_kernel_evr)"
	if [[ "${PURPLEFIN_DELL_IPU7_KERNEL_ALLOW_UNPINNED:-0}" == "1" ]]; then
		if ((${#supported_71[@]} > 0)); then
			printf '%s\n' "${supported_71[@]}" | sort -Vr | head -n 1
			return 0
		fi
		return 1
	fi

	if purplefin_dell_ipu7_kernel_evr_denied "${default_evr#0:}"; then
		return 1
	fi

	for line in "${supported_71[@]}"; do
		if [[ "${line}" == "${default_evr#0:}" ]]; then
			printf '%s\n' "${line}"
			return 0
		fi
	done

	return 1
}

purplefin_dell_ipu7_package_spec_from_repoquery() {
	local package="$1"
	local target_evr="$2"
	local target_arch="$3"

	awk -F '\t' -v package="${package}" -v target_evr="${target_evr#0:}" -v target_arch="${target_arch}" '
		$1 == package && $2 == target_evr && ($3 == target_arch || $3 == "noarch") {
			print $1 "-" $2 "." $3
			found = 1
			exit
		}
		END { exit found ? 0 : 1 }
	'
}

purplefin_dell_ipu7_collect_package_specs_from_repoquery() {
	local target_evr="$1"
	local target_arch="$2"
	shift 2
	local repoquery package spec repoquery_tmp

	repoquery="$(cat)"
	repoquery_tmp="$(mktemp)"
	printf '%s\n' "${repoquery}" >"${repoquery_tmp}"
	for package in "$@"; do
		spec="$(purplefin_dell_ipu7_package_spec_from_repoquery "${package}" "${target_evr}" "${target_arch}" <"${repoquery_tmp}")" || {
			rm -f "${repoquery_tmp}"
			return 1
		}
		printf '%s\n' "${spec}"
	done
	rm -f "${repoquery_tmp}"
}

purplefin_dell_ipu7_required_kernel_configs() {
	local configs="${PURPLEFIN_DELL_IPU7_REQUIRED_KERNEL_CONFIGS:-CONFIG_IPU_BRIDGE CONFIG_VIDEO_INTEL_IPU7 CONFIG_VIDEO_OV02C10 CONFIG_USB_USBIO CONFIG_GPIO_USBIO CONFIG_I2C_USBIO}"

	printf '%s\n' ${configs}
}

purplefin_dell_ipu7_validate_kernel_config_file() {
	local config_file="$1"
	local config

	[[ -f "${config_file}" ]] || return 1
	while IFS= read -r config; do
		[[ -n "${config}" ]] || continue
		if ! grep -Eq "^${config}=(y|m)$" "${config_file}"; then
			purplefin_dell_ipu7_log "target kernel config ${config_file} does not enable ${config}"
			return 1
		fi
	done < <(purplefin_dell_ipu7_required_kernel_configs)
}

purplefin_dell_ipu7_find_local_kernel_config() {
	local release="$1"
	local config_file

	for config_file in \
		"/usr/lib/modules/${release}/config" \
		"/lib/modules/${release}/config" \
		"/boot/config-${release}"; do
		if [[ -f "${config_file}" ]]; then
			printf '%s\n' "${config_file}"
			return 0
		fi
	done

	return 1
}

purplefin_dell_ipu7_fstab_has_root_mount_entry() {
	local fstab="${1:-/etc/fstab}"

	[[ -f "${fstab}" ]] || return 1
	awk '
		/^[[:space:]]*($|#)/ { next }
		{
			if ($2 == "/") {
				found = 1
				exit
			}
		}
		END { exit found ? 0 : 1 }
	' "${fstab}"
}

purplefin_dell_ipu7_kernel_repo_id() {
	printf '%s\n' "${PURPLEFIN_DELL_IPU7_KERNEL_REPO_ID:-copr:copr.fedorainfracloud.org:group_kernel-vanilla:stable}"
}

purplefin_dell_ipu7_kernel_repo_baseurl() {
	printf '%s\n' "${PURPLEFIN_DELL_IPU7_KERNEL_REPO_BASEURL:-https://download.copr.fedorainfracloud.org/results/@kernel-vanilla/stable/fedora-\$releasever-\$basearch/}"
}

purplefin_dell_ipu7_kernel_repo_gpgkey() {
	printf '%s\n' "${PURPLEFIN_DELL_IPU7_KERNEL_REPO_GPGKEY:-https://download.copr.fedorainfracloud.org/results/@kernel-vanilla/stable/pubkey.gpg}"
}
