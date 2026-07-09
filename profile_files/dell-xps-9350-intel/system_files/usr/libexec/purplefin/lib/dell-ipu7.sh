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

purplefin_dell_ipu7_kernel_state_dir() {
	printf '%s\n' "${PURPLEFIN_DELL_IPU7_STATE_DIR:-/var/lib/purplefin/dell-ipu7}"
}

purplefin_dell_ipu7_kernel_pending_file() {
	printf '%s/kernel-staged.pending\n' "$(purplefin_dell_ipu7_kernel_state_dir)"
}

purplefin_dell_ipu7_kernel_ok_file() {
	printf '%s/kernel-booted.ok\n' "$(purplefin_dell_ipu7_kernel_state_dir)"
}

purplefin_dell_ipu7_kernel_denylist_file() {
	printf '%s\n' "${PURPLEFIN_DELL_IPU7_KERNEL_DENYLIST:-/usr/share/purplefin/dell-ipu7/kernel-evr.denylist}"
}

purplefin_dell_ipu7_uname_r() {
	if [[ -n "${PURPLEFIN_DELL_IPU7_UNAME_R:-}" ]]; then
		printf '%s\n' "${PURPLEFIN_DELL_IPU7_UNAME_R}"
	else
		uname -r
	fi
}

purplefin_dell_ipu7_uname_m() {
	if [[ -n "${PURPLEFIN_DELL_IPU7_UNAME_M:-}" ]]; then
		printf '%s\n' "${PURPLEFIN_DELL_IPU7_UNAME_M}"
	else
		uname -m
	fi
}

purplefin_dell_ipu7_kernel_supported() {
	local release="${1:-}"
	local lower

	[[ -n "${release}" ]] || return 1
	lower="${release,,}"
	[[ "${lower}" != *rc* ]] || return 1

	[[ "${release}" =~ (^|[^0-9])7\.1\.[0-9]+([^0-9]|$) ]]
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

purplefin_dell_ipu7_booted_kernel_evr() {
	local release arch

	release="$(purplefin_dell_ipu7_uname_r)"
	arch="$(purplefin_dell_ipu7_uname_m)"

	if [[ "${release}" == *".${arch}" ]]; then
		printf '%s\n' "${release%."${arch}"}"
	else
		printf '%s\n' "${release}"
	fi
}

purplefin_dell_ipu7_kernel_release_matches_evr() {
	local release="$1"
	local evr="$2"
	local arch="${3:-$(purplefin_dell_ipu7_uname_m)}"

	[[ "${release}" == "${evr#0:}" || "${release}" == "$(purplefin_dell_ipu7_kernel_release_for_evr_arch "${evr}" "${arch}")" ]]
}

purplefin_dell_ipu7_state_value() {
	local file="$1"
	local key="$2"

	[[ -f "${file}" ]] || return 1
	awk -F '=' -v key="${key}" '$1 == key { sub(/^[^=]*=/, ""); print; found = 1; exit } END { exit found ? 0 : 1 }' "${file}"
}

purplefin_dell_ipu7_state_values() {
	local file="$1"
	local key="$2"

	[[ -f "${file}" ]] || return 1
	awk -F '=' -v key="${key}" '$1 == key { sub(/^[^=]*=/, ""); print; found = 1 } END { exit found ? 0 : 1 }' "${file}"
}

purplefin_dell_ipu7_pending_kernel_evr() {
	purplefin_dell_ipu7_state_value "$(purplefin_dell_ipu7_kernel_pending_file)" target_evr
}

purplefin_dell_ipu7_ok_kernel_evr() {
	purplefin_dell_ipu7_state_value "$(purplefin_dell_ipu7_kernel_ok_file)" target_evr
}

purplefin_dell_ipu7_record_kernel_staged() {
	local evr="$1"
	local release="$2"
	shift 2
	local state_dir pending tmp build_package

	state_dir="$(purplefin_dell_ipu7_kernel_state_dir)"
	pending="$(purplefin_dell_ipu7_kernel_pending_file)"
	install -d -m 0755 "${state_dir}"
	tmp="$(mktemp "${state_dir}/kernel-staged.pending.XXXXXX")"
	{
		printf 'target_evr=%s\n' "${evr#0:}"
		printf 'target_release=%s\n' "${release}"
		for build_package in "$@"; do
			printf 'build_package=%s\n' "${build_package}"
		done
	} >"${tmp}"
	chmod 0644 "${tmp}"
	mv -f "${tmp}" "${pending}"
	rm -f "$(purplefin_dell_ipu7_kernel_ok_file)"
}

purplefin_dell_ipu7_record_kernel_booted_ok() {
	local evr="$1"
	local release="$2"
	shift 2
	local state_dir ok tmp build_package

	state_dir="$(purplefin_dell_ipu7_kernel_state_dir)"
	ok="$(purplefin_dell_ipu7_kernel_ok_file)"
	install -d -m 0755 "${state_dir}"
	tmp="$(mktemp "${state_dir}/kernel-booted.ok.XXXXXX")"
	{
		printf 'target_evr=%s\n' "${evr#0:}"
		printf 'target_release=%s\n' "${release}"
		for build_package in "$@"; do
			printf 'build_package=%s\n' "${build_package}"
		done
	} >"${tmp}"
	chmod 0644 "${tmp}"
	mv -f "${tmp}" "${ok}"
	rm -f "$(purplefin_dell_ipu7_kernel_pending_file)"
}

purplefin_dell_ipu7_mark_booted_kernel_ok_if_pending() {
	local pending evr release
	local build_packages=()

	pending="$(purplefin_dell_ipu7_kernel_pending_file)"
	[[ -f "${pending}" ]] || return 1

	evr="$(purplefin_dell_ipu7_state_value "${pending}" target_evr)" || return 1
	release="$(purplefin_dell_ipu7_uname_r)"
	if ! purplefin_dell_ipu7_kernel_release_matches_evr "${release}" "${evr}"; then
		return 1
	fi

	mapfile -t build_packages < <(purplefin_dell_ipu7_state_values "${pending}" build_package || true)
	purplefin_dell_ipu7_record_kernel_booted_ok "${evr}" "${release}" "${build_packages[@]}"
	return 0
}

purplefin_dell_ipu7_refuse_failed_kernel_stage() {
	local pending evr release

	pending="$(purplefin_dell_ipu7_kernel_pending_file)"
	[[ -f "${pending}" ]] || return 1

	evr="$(purplefin_dell_ipu7_state_value "${pending}" target_evr || true)"
	release="$(purplefin_dell_ipu7_uname_r)"
	purplefin_dell_ipu7_log "Dell IPU7 kernel ${evr:-unknown} was staged but the system is booted into ${release}; this looks like a failed boot or manual rollback, so IPU7 tasks are stopped until the pending marker is cleared or the target kernel boots"
	return 0
}

purplefin_dell_ipu7_assert_booted_kernel() {
	local release ok_evr

	if purplefin_dell_ipu7_mark_booted_kernel_ok_if_pending; then
		purplefin_dell_ipu7_log "confirmed boot into staged Dell IPU7 kernel $(purplefin_dell_ipu7_uname_r)"
	fi

	if purplefin_dell_ipu7_refuse_failed_kernel_stage; then
		return 1
	fi

	release="$(purplefin_dell_ipu7_uname_r)"
	ok_evr="$(purplefin_dell_ipu7_ok_kernel_evr || true)"
	if [[ -n "${ok_evr}" ]]; then
		if purplefin_dell_ipu7_kernel_release_matches_evr "${release}" "${ok_evr}"; then
			return 0
		fi

		purplefin_dell_ipu7_log "refusing Dell IPU7 setup on ${release}; validated Dell IPU7 kernel is ${ok_evr}"
		return 1
	fi

	if [[ "${PURPLEFIN_DELL_IPU7_ALLOW_UNMARKED_KERNEL:-0}" == "1" ]] && purplefin_dell_ipu7_kernel_supported "${release}"; then
		return 0
	fi

	if purplefin_dell_ipu7_kernel_supported "${release}"; then
		purplefin_dell_ipu7_log "refusing Dell IPU7 setup on ${release}; no validated Dell IPU7 kernel marker exists"
	else
		purplefin_dell_ipu7_log "refusing Dell IPU7 setup on unsupported kernel ${release}; boot the validated Dell IPU7 Linux 7.1.x kernel first"
	fi
	return 1
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
	local configs="${PURPLEFIN_DELL_IPU7_REQUIRED_KERNEL_CONFIGS:-CONFIG_IPU_BRIDGE CONFIG_INTEL_SKL_INT3472 CONFIG_VIDEO_INTEL_IPU7 CONFIG_VIDEO_OV08X40}"

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

purplefin_dell_ipu7_kernel_build_packages_from_state() {
	local ok pending file

	ok="$(purplefin_dell_ipu7_kernel_ok_file)"
	pending="$(purplefin_dell_ipu7_kernel_pending_file)"
	file=""
	if [[ -f "${ok}" ]]; then
		file="${ok}"
	elif [[ -f "${pending}" ]]; then
		file="${pending}"
	fi

	if [[ -n "${file}" ]]; then
		purplefin_dell_ipu7_state_values "${file}" build_package
		return $?
	fi

	return 1
}

purplefin_dell_ipu7_default_kernel_build_packages() {
	local evr="${1:-$(purplefin_dell_ipu7_booted_kernel_evr)}"
	local arch="${2:-$(purplefin_dell_ipu7_uname_m)}"

	printf 'kernel-devel-%s.%s\n' "${evr#0:}" "${arch}"
	printf 'kernel-devel-matched-%s.noarch\n' "${evr#0:}"
	printf 'kernel-headers-%s.%s\n' "${evr#0:}" "${arch}"
}

purplefin_dell_ipu7_effective_kernel_build_packages() {
	if purplefin_dell_ipu7_kernel_build_packages_from_state; then
		return 0
	fi

	purplefin_dell_ipu7_default_kernel_build_packages
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

purplefin_dell_ipu7_validate_installed_kernel_build_stack() {
	local release evr arch build_link

	release="$(purplefin_dell_ipu7_uname_r)"
	evr="$(purplefin_dell_ipu7_booted_kernel_evr)"
	arch="$(purplefin_dell_ipu7_uname_m)"
	build_link="/usr/lib/modules/${release}/build"

	command -v rpm >/dev/null 2>&1 || {
		purplefin_dell_ipu7_log "rpm is required to validate Dell IPU7 kernel build packages"
		return 1
	}

	rpm -q --whatprovides "kernel-devel-uname-r = ${release}" >/dev/null 2>&1 || {
		purplefin_dell_ipu7_log "kernel-devel for ${release} is missing; install the exact Dell IPU7 kernel-devel package before DKMS"
		return 1
	}
	rpm -q "kernel-devel-matched-${evr}.noarch" >/dev/null 2>&1 || rpm -q "kernel-devel-matched-${evr}.${arch}" >/dev/null 2>&1 || {
		purplefin_dell_ipu7_log "kernel-devel-matched for ${evr} is missing or mismatched"
		return 1
	}
	rpm -q "kernel-headers-${evr}.${arch}" >/dev/null 2>&1 || {
		purplefin_dell_ipu7_log "kernel-headers for ${evr}.${arch} is missing or mismatched"
		return 1
	}
	[[ -e "${build_link}/Makefile" ]] || {
		purplefin_dell_ipu7_log "kernel build tree ${build_link} is missing"
		return 1
	}
}
