#!/usr/bin/env bash
set -euo pipefail

nextcloud_version="33.0.7"
nextcloud_sha256="fd7549564c6b2bab5f984fa5d7df0d05c9b751017ac4b2bd9ccdf48981053074"
nextcloud_filename="Nextcloud-${nextcloud_version}-x86_64.AppImage"
nextcloud_url="https://github.com/nextcloud-releases/desktop/releases/download/v${nextcloud_version}/${nextcloud_filename}"

if [[ "$(uname -m)" != "x86_64" ]]; then
	echo "The pinned Nextcloud AppImage is only available for x86_64" >&2
	exit 1
fi

work_dir="$(mktemp -d)"
trap 'rm -rf "${work_dir}"' EXIT

download="${work_dir}/${nextcloud_filename}"
installed_appimage="/usr/libexec/purplefin/appimages/Nextcloud.AppImage"

curl --fail --location --retry 5 --retry-all-errors \
	--output "${download}" "${nextcloud_url}"
printf '%s  %s\n' "${nextcloud_sha256}" "${download}" | sha256sum --check --strict -

install -Dm0755 "${download}" "${installed_appimage}"
ln -sfn "${installed_appimage}" /usr/bin/nextcloud

(
	cd "${work_dir}"
	"${installed_appimage}" --appimage-extract \
		'usr/share/applications/com.nextcloud.desktopclient.nextcloud.desktop' >/dev/null
	"${installed_appimage}" --appimage-extract \
		'usr/share/icons/hicolor/512x512/apps/Nextcloud.png' >/dev/null
)

desktop_file="${work_dir}/squashfs-root/usr/share/applications/com.nextcloud.desktopclient.nextcloud.desktop"
icon_file="${work_dir}/squashfs-root/usr/share/icons/hicolor/512x512/apps/Nextcloud.png"
test -f "${desktop_file}"
test -f "${icon_file}"
sed -i 's|^Exec=.*|Exec=/usr/bin/nextcloud %u|' "${desktop_file}"
install -Dm0644 "${desktop_file}" \
	/usr/share/applications/com.nextcloud.desktopclient.nextcloud.desktop
install -Dm0644 "${icon_file}" \
	/usr/share/icons/hicolor/512x512/apps/Nextcloud.png

install -d /usr/share/purplefin
printf 'version=%s\nurl=%s\nsha256=%s\n' \
	"${nextcloud_version}" "${nextcloud_url}" "${nextcloud_sha256}" \
	>/usr/share/purplefin/nextcloud-appimage.provenance

desktop-file-validate /usr/share/applications/com.nextcloud.desktopclient.nextcloud.desktop
test -x /usr/bin/nextcloud
/usr/bin/nextcloud --appimage-version
