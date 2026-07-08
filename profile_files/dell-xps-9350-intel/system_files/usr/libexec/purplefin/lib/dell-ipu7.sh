#!/usr/bin/env bash
# Shared helpers for Dell IPU7 first-boot setup.

purplefin_dell_ipu7_log() {
	if declare -F purplefin_firstboot_log >/dev/null 2>&1; then
		purplefin_firstboot_log "$@"
	else
		printf 'purplefin-dell-ipu7: %s\n' "$*" >&2
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

purplefin_dell_ipu7_assert_booted_kernel() {
	local release

	release="$(uname -r)"
	if purplefin_dell_ipu7_kernel_supported "${release}"; then
		return 0
	fi

	purplefin_dell_ipu7_log "refusing Dell IPU7 setup on unsupported kernel ${release}; boot a stable Linux 7.1.x kernel first"
	return 1
}

purplefin_dell_ipu7_select_kernel_evr() {
	local line lower
	local supported_71=()

	while IFS= read -r line; do
		[[ -n "${line}" ]] || continue
		lower="${line,,}"
		[[ "${lower}" != *rc* ]] || continue

		if [[ "${line}" =~ (^|[^0-9])7\.1\.[0-9]+([^0-9]|$) ]]; then
			supported_71+=("${line}")
		fi
	done

	if ((${#supported_71[@]} > 0)); then
		printf '%s\n' "${supported_71[@]}" | sort -Vr | head -n 1
		return 0
	fi

	return 1
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
