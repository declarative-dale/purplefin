#!/usr/bin/env bash
set -euo pipefail

metadata_file="${PURPLEFIN_BITWARDEN_CLI_METADATA:-$(dirname "$0")/bitwarden-cli.env}"
api_url="${PURPLEFIN_BITWARDEN_RELEASES_API:-https://api.github.com/repos/bitwarden/clients/releases?per_page=100}"
workdir="$(mktemp -d)"

cleanup() {
	rm -rf "${workdir}"
}
trap cleanup EXIT

for command in curl jq sha256sum; do
	command -v "${command}" >/dev/null 2>&1 || {
		echo "${command} is required to update Bitwarden CLI metadata" >&2
		exit 1
	}
done

curl_args=(
	--fail
	--location
	--show-error
	--silent
	--retry 3
	--retry-delay 2
	--header "Accept: application/vnd.github+json"
	--header "X-GitHub-Api-Version: 2022-11-28"
)
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
	curl_args+=(--header "Authorization: Bearer ${GITHUB_TOKEN}")
fi

releases_json="${workdir}/releases.json"
curl "${curl_args[@]}" --output "${releases_json}" "${api_url}"

tag="$(${JQ:-jq} -er \
	'[.[] | select(.draft == false and .prerelease == false and (.tag_name | startswith("cli-v")))][0].tag_name' \
	"${releases_json}")"
version="${tag#cli-v}"
if [[ ! "${version}" =~ ^[0-9]+([.][0-9]+)+$ ]]; then
	echo "GitHub returned an invalid Bitwarden CLI release tag: ${tag}" >&2
	exit 1
fi

asset_name="bw-linux-${version}.zip"
digest="$(${JQ:-jq} -er --arg tag "${tag}" --arg asset "${asset_name}" \
	'.[] | select(.tag_name == $tag) | .assets[] | select(.name == $asset) | .digest' \
	"${releases_json}")"
sha256="${digest#sha256:}"
if [[ "${digest}" != sha256:* || ! "${sha256}" =~ ^[0-9a-f]{64}$ ]]; then
	echo "GitHub returned an invalid digest for ${asset_name}: ${digest}" >&2
	exit 1
fi

tmp_metadata="${workdir}/bitwarden-cli.env"
printf '%s\n' \
	"# Updated by build_files/update-bitwarden-cli.sh from Bitwarden's official GitHub release." \
	"BITWARDEN_CLI_VERSION=${version}" \
	"BITWARDEN_CLI_SHA256=${sha256}" >"${tmp_metadata}"

if [[ -f "${metadata_file}" ]] && cmp -s "${tmp_metadata}" "${metadata_file}"; then
	echo "Bitwarden CLI ${version} is already pinned"
	exit 0
fi

asset_url="https://github.com/bitwarden/clients/releases/download/${tag}/${asset_name}"
asset_path="${workdir}/${asset_name}"
echo "Verifying ${asset_name} against GitHub's published digest"
curl --fail --location --show-error --silent --retry 3 --retry-delay 2 \
	--output "${asset_path}" "${asset_url}"
printf '%s  %s\n' "${sha256}" "${asset_path}" | sha256sum --check --strict

install -m 0644 "${tmp_metadata}" "${metadata_file}"
echo "Updated Bitwarden CLI metadata to ${version}"
