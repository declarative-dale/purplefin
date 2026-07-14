#!/usr/bin/env bash
# Shared helpers for applying a role's filesystem and Flatpak manifest fragments.

purplefin_apply_role_overlay() {
	local role="$1"
	local role_root="/tmp/purplefin-profile-files/roles/${role}"
	local system_root="${role_root}/system_files"
	local flatpak_manifest="${role_root}/manifests/flatpaks.preinstall"

	if [[ -d "${system_root}" ]]; then
		cp -a "${system_root}/." /
	fi

	if [[ -f "${flatpak_manifest}" ]]; then
		install -D -m 0644 "${flatpak_manifest}" \
			"/usr/share/flatpak/preinstall.d/purplefin-${role}.preinstall"
	fi
}
