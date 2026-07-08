image := "ghcr.io/declarative-dale/purplefin"

default:
    @just --list

check:
    #!/usr/bin/env bash
    set -euo pipefail

    find build_files system_files/usr/libexec/purplefin profile_files -type f \( -name '*.sh' -o -perm -111 \) -exec bash -n {} +

    tmpdir="$(mktemp -d)"
    refind_tmp="$(mktemp -d)"
    trap 'rm -rf "${tmpdir}" "${refind_tmp}"' EXIT
    cp -a system_files/. "${tmpdir}/"
    cp -a profile_files/dell-xps-9350-intel/system_files/. "${tmpdir}/"
    install -d "${tmpdir}/usr/lib/systemd/system"
    printf '%s\n' '[Unit]' 'Description=System Initialization' > "${tmpdir}/usr/lib/systemd/system/sysinit.target"
    printf '%s\n' '[Unit]' 'Description=Local File Systems' > "${tmpdir}/usr/lib/systemd/system/local-fs.target"
    printf '%s\n' '[Unit]' 'Description=Basic System' 'Requires=sysinit.target' 'After=sysinit.target' > "${tmpdir}/usr/lib/systemd/system/basic.target"
    printf '%s\n' '[Unit]' 'Description=Multi-User System' 'Requires=basic.target' 'After=basic.target' > "${tmpdir}/usr/lib/systemd/system/multi-user.target"
    systemd-analyze verify --root="${tmpdir}" /usr/lib/systemd/system/purplefin-firstboot-rpm-ostree.service /usr/lib/systemd/system/purplefin-brew-bundle.service /usr/lib/systemd/system/purplefin-refind-theme.service

    test -f manifests/Brewfile
    test -f manifests/flatpaks.preinstall
    test -f system_files/etc/skel/.config/ghostty/config.ghostty
    test -f system_files/usr/share/purplefin/ghostty/config.ghostty
    cmp -s system_files/etc/skel/.config/ghostty/config.ghostty system_files/usr/share/purplefin/ghostty/config.ghostty
    test -x system_files/usr/libexec/purplefin/install-ghostty-defaults
    test -f system_files/usr/lib/systemd/user/purplefin-ghostty-defaults.service
    test -L system_files/etc/systemd/user/default.target.wants/purplefin-ghostty-defaults.service
    grep -qx 'copy-on-select = clipboard' system_files/etc/skel/.config/ghostty/config.ghostty
    grep -qx 'right-click-action = paste' system_files/etc/skel/.config/ghostty/config.ghostty
    test ! -e system_files/etc/xdg/xdg-terminals.list
    test ! -e system_files/etc/xdg/gnome-xdg-terminals.list
    grep -qx 'excludepkgs=1password\*' system_files/etc/yum.repos.d/terra.repo
    test -f system_files/usr/share/plymouth/themes/spinner/watermark.png
    test -f system_files/usr/share/plymouth/themes/spinner/silverblue-watermark.png
    test -f system_files/usr/share/pixmaps/fedora-gdm-logo.png
    file system_files/usr/share/plymouth/themes/spinner/watermark.png | grep -q 'PNG image data, 149 x 43'
    file system_files/usr/share/plymouth/themes/spinner/silverblue-watermark.png | grep -q 'PNG image data, 149 x 43'
    file system_files/usr/share/pixmaps/fedora-gdm-logo.png | grep -q 'PNG image data, 150 x 61'
    cmp -s system_files/usr/share/plymouth/themes/spinner/watermark.png system_files/usr/share/plymouth/themes/spinner/silverblue-watermark.png
    for logo in bluefin chicken dolly karl; do
        test -f "system_files/usr/share/ublue-os/bluefin-logos/${logo}.png"
        file "system_files/usr/share/ublue-os/bluefin-logos/${logo}.png" | grep -q 'PNG image data, 1000 x 1000'
        cmp -s "system_files/usr/share/ublue-os/bluefin-logos/${logo}.png" profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/icons/os_purplefin.png
    done
    grep -qF 'dracut --force "${kernel_modules_dir}/initramfs.img" "${kernel_version}"' build_files/build.sh
    test -x system_files/usr/libexec/purplefin/run-firstboot-rpm-ostree
    test ! -e system_files/etc/yum.repos.d/1password.repo
    test ! -e system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/10-1password-desktop-layer
    test -f profile_files/dell-xps-9350-intel/system_files/etc/yum.repos.d/1password.repo
    test ! -e profile_files/dell-xps-9350-intel/system_files/etc/plymouth
    test -x profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/10-1password-desktop-layer
    test ! -e profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/50-dell-vates-plymouth-initramfs
    test -x profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/install-refind-theme
    test -f profile_files/dell-xps-9350-intel/system_files/usr/lib/systemd/system/purplefin-refind-theme.service
    test -f profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/theme.conf
    test -f profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/icons/os_fedora.png
    test -f profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/fonts/source-code-pro-extralight-14.png
    test -f profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/icons/os_win11.png
    test -f profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/icons/os_windows.png
    test -f profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/icons/os_bluefin.png
    test -f profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/icons/os_purplefin.png
    cmp -s profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/icons/os_bluefin.png profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/icons/os_purplefin.png
    cmp -s profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/icons/os_bluefin.png profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/icons/os_fedora.png
    cmp -s profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/icons/os_bluefin.png profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/icons/os_linux.png
    unexpected_refind_distro_icon="$(find profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/icons -type f -name 'os_*.png' ! -path '*/icons/os_win.png' ! -path '*/icons/os_win8.png' ! -path '*/icons/os_win11.png' ! -path '*/icons/os_windows.png' ! -path '*/icons/os_bluefin.png' ! -path '*/icons/os_purplefin.png' ! -path '*/icons/os_fedora.png' ! -path '*/icons/os_linux.png' -print -quit)"
    test -z "${unexpected_refind_distro_icon}"
    grep -qx 'icons_dir themes/rEFInd-Regular-Dark/icons' profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/theme.conf
    ! grep -q '^menuentry ' profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark/theme.conf

    refind_installer="profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/install-refind-theme"
    refind_theme_source="profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/refind/themes/rEFInd-Regular-Dark"
    mkdir -p "${refind_tmp}/EFI/refind/themes/rEFInd-Regular-Dark/icons"
    printf '%s\n' 'timeout 5' > "${refind_tmp}/EFI/refind/refind.conf"
    printf '%s\n' 'replace-existing-target-icon' > "${refind_tmp}/EFI/refind/themes/rEFInd-Regular-Dark/icons/os_linux.png"
    printf '%s\n' 'remove-stale-distro-icon' > "${refind_tmp}/EFI/refind/themes/rEFInd-Regular-Dark/icons/os_ubuntu.png"
    for run in 1 2; do
        PURPLEFIN_REFIND_DIR="${refind_tmp}/EFI/refind" PURPLEFIN_REFIND_THEME_SOURCE="${PWD}/${refind_theme_source}" "${refind_installer}" >/dev/null 2>&1
    done
    cmp -s "${refind_theme_source}/icons/os_linux.png" "${refind_tmp}/EFI/refind/themes/rEFInd-Regular-Dark/icons/os_linux.png"
    cmp -s "${refind_theme_source}/icons/os_win11.png" "${refind_tmp}/EFI/refind/themes/rEFInd-Regular-Dark/icons/os_win11.png"
    test ! -e "${refind_tmp}/EFI/refind/themes/rEFInd-Regular-Dark/icons/os_ubuntu.png"
    test "$(grep -c '^include themes/rEFInd-Regular-Dark/theme.conf$' "${refind_tmp}/EFI/refind/refind.conf")" -eq 1

build-generic:
    podman build --build-arg BUILD_PROFILE=generic-x86_64 --tag {{image}}:generic-x86_64 .

build-dell:
    podman build --build-arg BUILD_PROFILE=dell-xps-9350-intel --tag {{image}}:dell-xps-9350-intel .

lint-generic:
    podman run --rm --entrypoint bootc {{image}}:generic-x86_64 container lint

lint-dell:
    podman run --rm --entrypoint bootc {{image}}:dell-xps-9350-intel container lint
