#!/usr/bin/env bash
# Shared helpers for Purplefin first-boot rpm-ostree tasks.

purplefin_firstboot_log() {
	printf 'purplefin-firstboot-rpm-ostree: %s\n' "$*" >&2
}

run_rpm_ostree() {
	local attempt output status
	local max_attempts="${PURPLEFIN_RPM_OSTREE_RETRIES:-10}"
	local retry_delay="${PURPLEFIN_RPM_OSTREE_RETRY_DELAY:-15}"

	for ((attempt = 1; attempt <= max_attempts; attempt++)); do
		if output="$(rpm-ostree "$@" 2>&1)"; then
			[[ -n "${output}" ]] && printf '%s\n' "${output}"
			return 0
		fi

		status=$?
		[[ -n "${output}" ]] && printf '%s\n' "${output}" >&2

		if [[ "${output}" != *"Transaction in progress"* ]] || ((attempt == max_attempts)); then
			return "${status}"
		fi

		purplefin_firstboot_log "rpm-ostree transaction already in progress; retrying in ${retry_delay}s (${attempt}/${max_attempts})"
		sleep "${retry_delay}"
	done
}
