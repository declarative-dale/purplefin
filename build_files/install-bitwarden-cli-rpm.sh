#!/usr/bin/env bash
set -euo pipefail

cli_url="${PURPLEFIN_BITWARDEN_CLI_URL:-https://vault.bitwarden.com/download/?app=cli&platform=linux}"
spec_file="${PURPLEFIN_BITWARDEN_CLI_SPEC:-/tmp/purplefin-build/bitwarden-cli.spec}"
workdir="$(mktemp -d)"
rpm_build_packages=()

cleanup() {
	rm -rf "${workdir}"
}
trap cleanup EXIT

[[ "$(uname -m)" == "x86_64" ]] || {
	echo "The official Bitwarden CLI RPM wrapper currently supports x86_64 only" >&2
	exit 1
}
for command in curl sha256sum unzip; do
	command -v "${command}" >/dev/null 2>&1 || {
		echo "${command} is required to build the official Bitwarden CLI RPM" >&2
		exit 1
	}
done
[[ -f "${spec_file}" ]] || {
	echo "Missing Bitwarden CLI RPM spec: ${spec_file}" >&2
	exit 1
}

if ! command -v rpmbuild >/dev/null 2>&1; then
	rpm -qa --qf '%{NAME}\n' | sort -u >"${workdir}/packages-before-rpmbuild"
	dnf5 -y --setopt=install_weak_deps=False install rpm-build
	mapfile -t rpm_build_packages < <(
		comm -13 "${workdir}/packages-before-rpmbuild" <(rpm -qa --qf '%{NAME}\n' | sort -u)
	)
fi

cli_zip="${workdir}/bw.zip"
cli_binary="${workdir}/bw"
provenance="${workdir}/bitwarden-cli.provenance"
cli_home="${workdir}/home"

echo ":: Building native RPM from Bitwarden's official CLI"
curl --fail --location --show-error --silent --retry 3 --retry-delay 2 --output "${cli_zip}" "${cli_url}"
unzip -p "${cli_zip}" bw >"${cli_binary}"
chmod 0755 "${cli_binary}"
install -d "${cli_home}/.config"

cli_version="$(HOME="${cli_home}" XDG_CONFIG_HOME="${cli_home}/.config" "${cli_binary}" --version)"
cli_version="${cli_version#v}"
if [[ ! "${cli_version}" =~ ^[0-9]+([.][0-9]+)+$ ]]; then
	echo "Unexpected Bitwarden CLI version: ${cli_version}" >&2
	exit 1
fi
cli_sha256="$(sha256sum "${cli_binary}" | awk '{print $1}')"
printf 'source_url=%s\nversion=%s\nsha256=%s\n' \
	"${cli_url}" "${cli_version}" "${cli_sha256}" >"${provenance}"

install -d "${workdir}/rpmbuild/BUILD" "${workdir}/rpmbuild/BUILDROOT" \
	"${workdir}/rpmbuild/RPMS" "${workdir}/rpmbuild/SOURCES" "${workdir}/rpmbuild/SPECS" \
	"${workdir}/rpmbuild/SRPMS"
rpmbuild -bb \
	--define "_topdir ${workdir}/rpmbuild" \
	--define "_sourcedir ${workdir}" \
	--define "cli_version ${cli_version}" \
	"${spec_file}"

rpm_path="$(find "${workdir}/rpmbuild/RPMS" -type f -name 'purplefin-bitwarden-cli-*.rpm' -print -quit)"
[[ -n "${rpm_path}" ]] || {
	echo "Bitwarden CLI RPM was not produced" >&2
	exit 1
}
dnf5 -y install "${rpm_path}"

if ((${#rpm_build_packages[@]} > 0)); then
	dnf5 -y remove --no-autoremove "${rpm_build_packages[@]}"
	for package in "${rpm_build_packages[@]}"; do
		if rpm -q "${package}" >/dev/null 2>&1; then
			echo "Temporary RPM build dependency is still installed: ${package}" >&2
			exit 1
		fi
	done
fi

rpm -q purplefin-bitwarden-cli
test "$(rpm -qf --qf '%{NAME}\n' /usr/bin/bw)" = "purplefin-bitwarden-cli"
test "$(sha256sum /usr/bin/bw | awk '{print $1}')" = "${cli_sha256}"
test "$(HOME="${cli_home}" XDG_CONFIG_HOME="${cli_home}/.config" bw --version)" = "${cli_version}"
