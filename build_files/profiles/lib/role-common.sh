#!/usr/bin/env bash
# Shared helpers for applying department and reusable-component overlays.

purplefin_apply_overlay() {
	local collection="$1"
	local name="$2"
	local manifest_name="$3"
	local profile_files_root="${PURPLEFIN_PROFILE_FILES_ROOT:-/tmp/purplefin-profile-files}"
	local overlay_root="${profile_files_root}/${collection}/${name}"
	local system_root="${overlay_root}/system_files"
	local flatpak_manifest="${overlay_root}/manifests/flatpaks.preinstall"

	if [[ -d "${system_root}" ]]; then
		cp -a "${system_root}/." /
	fi

	if [[ -f "${flatpak_manifest}" ]]; then
		install -D -m 0644 "${flatpak_manifest}" \
			"/usr/share/flatpak/preinstall.d/${manifest_name}.preinstall"
	fi
}

purplefin_apply_role_overlay() {
	local role="$1"
	purplefin_apply_overlay roles "${role}" "purplefin-${role}"
}

purplefin_apply_component_overlay() {
	local component="$1"
	purplefin_apply_overlay components "${component}" "purplefin-component-${component}"
}
