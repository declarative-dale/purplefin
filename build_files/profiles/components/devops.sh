#!/usr/bin/env bash
set -euo pipefail

component=devops
build_root="${PURPLEFIN_BUILD_ROOT:-/tmp/purplefin-build}"
profile_files_root="${PURPLEFIN_PROFILE_FILES_ROOT:-/tmp/purplefin-profile-files}"
component_state_dir="${PURPLEFIN_COMPONENT_STATE_DIR:-${build_root}/.component-state}"
component_state="${component_state_dir}/${component}.applied"
component_root="${profile_files_root}/components/${component}"
package_manifest="${component_root}/manifests/rpms.list"

# shellcheck source=/tmp/purplefin-build/profiles/lib/role-common.sh
source "${build_root}/profiles/lib/role-common.sh"

if [[ -e "${component_state}" ]]; then
	echo ":: Devops component already applied"
	exit 0
fi

purplefin_apply_component_overlay "${component}"

test -f "${package_manifest}" || {
	echo "Missing ${component} RPM manifest: ${package_manifest}" >&2
	exit 1
}
mapfile -t devops_packages < <(
	awk 'NF && $1 !~ /^#/ { print $1 }' "${package_manifest}"
)
if ((${#devops_packages[@]} == 0)); then
	echo "The ${component} RPM manifest is empty" >&2
	exit 1
fi

echo ":: Installing devops component applications"
dnf5 -y install "${devops_packages[@]}"

chmod 0755 /usr/libexec/purplefin/install-ghostty-defaults
systemctl --global enable purplefin-ghostty-defaults.service

for package in "${devops_packages[@]}"; do
	rpm -q "${package}"
done
for command in ghostty ansible bao packer tofu; do
	command -v "${command}" >/dev/null
done

install -d -m 0755 "${component_state_dir}"
touch "${component_state}"
