image := "ghcr.io/declarative-dale/purplefin"

default:
    @just --list

check:
    #!/usr/bin/env bash
    set -euo pipefail

    find build_files system_files/usr/libexec/purplefin profile_files -type f \( -name '*.sh' -o -perm -111 \) -exec bash -n {} +

    tmpdir="$(mktemp -d)"
    refind_tmp="$(mktemp -d)"
    ipu7_psys_tmp="$(mktemp)"
    trap 'rm -rf "${tmpdir}" "${refind_tmp}" "${ipu7_psys_tmp}"' EXIT
    cp -a system_files/. "${tmpdir}/"
    cp -a profile_files/dell-xps-9350-intel/system_files/. "${tmpdir}/"
    install -d "${tmpdir}/usr/lib/systemd/system"
    install -d "${tmpdir}/usr/bin" "${tmpdir}/usr/sbin"
    printf '%s\n' '#!/usr/bin/env sh' 'exit 0' > "${tmpdir}/usr/bin/true"
    cp "${tmpdir}/usr/bin/true" "${tmpdir}/usr/sbin/modprobe"
    chmod 0755 "${tmpdir}/usr/bin/true" "${tmpdir}/usr/sbin/modprobe"
    printf '%s\n' '[Unit]' 'Description=System Initialization' > "${tmpdir}/usr/lib/systemd/system/sysinit.target"
    printf '%s\n' '[Unit]' 'Description=Local File Systems' > "${tmpdir}/usr/lib/systemd/system/local-fs.target"
    printf '%s\n' '[Unit]' 'Description=Basic System' 'Requires=sysinit.target' 'After=sysinit.target' > "${tmpdir}/usr/lib/systemd/system/basic.target"
    printf '%s\n' '[Unit]' 'Description=Multi-User System' 'Requires=basic.target' 'After=basic.target' > "${tmpdir}/usr/lib/systemd/system/multi-user.target"
    printf '%s\n' '[Unit]' 'Description=udev settle stub' '[Service]' 'Type=oneshot' 'ExecStart=/usr/bin/true' > "${tmpdir}/usr/lib/systemd/system/systemd-udev-settle.service"
    systemd-analyze verify --root="${tmpdir}" /usr/lib/systemd/system/purplefin-firstboot-rpm-ostree.service /usr/lib/systemd/system/purplefin-brew-bundle.service /usr/lib/systemd/system/purplefin-refind-theme.service /usr/lib/systemd/system/purplefin-dell-ipu7-psys-load.service /usr/lib/systemd/system/purplefin-dell-ipu7-v4l2loopback-load.service

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
    grep -qF 'PURPLEFIN_DELL_IPU7_KERNEL_EVR' Containerfile
    grep -qF 'PURPLEFIN_DELL_IPU7_KERNEL_ALLOW_UNPINNED' Containerfile
    ! grep -qF 'dracut --force "${kernel_modules_dir}/initramfs.img" "${kernel_version}"' build_files/build.sh
    grep -qF 'rm -f /boot/symvers-*.xz' build_files/build.sh
    grep -qF '/var/lib/rpm-state' build_files/build.sh
    test -x system_files/usr/libexec/purplefin/run-firstboot-rpm-ostree
    test -z "$(find system_files -iname '*ipu7*' -print -quit)"
    test ! -e system_files/etc/yum.repos.d/1password.repo
    test ! -e system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/10-1password-desktop-layer
    test -f profile_files/dell-xps-9350-intel/system_files/etc/yum.repos.d/1password.repo
    test ! -e profile_files/dell-xps-9350-intel/system_files/etc/plymouth
    test -x profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/10-1password-desktop-layer
    test -x profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/20-dell-ipu7-stable-kernel
    test -x profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/30-dell-ipu7-build-deps
    test -x profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/40-dell-ipu7-dkms-userspace
    test -x profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/dell-ipu7-patch-psys-debugfs
    test -x profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/dell-ipu7-setup
    test -f profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/lib/dell-ipu7.sh
    grep -qF 'install_ipu7_kernel' build_files/profiles/dell-xps-9350-intel.sh
    grep -qF 'remove_non_ipu7_runtime_kernels' build_files/profiles/dell-xps-9350-intel.sh
    grep -qF 'remove_inherited_v4l2loopback_kmods' build_files/profiles/dell-xps-9350-intel.sh
    grep -qF 'kernel-build-packages' build_files/profiles/dell-xps-9350-intel.sh
    ! grep -qF 'override replace' profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/20-dell-ipu7-stable-kernel
    grep -qF 'akmod-v4l2loopback' profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/30-dell-ipu7-build-deps
    test -f profile_files/dell-xps-9350-intel/system_files/usr/lib/systemd/system/purplefin-dell-ipu7-psys-load.service
    test -f profile_files/dell-xps-9350-intel/system_files/usr/lib/systemd/system/purplefin-dell-ipu7-v4l2loopback-load.service
    test -f profile_files/dell-xps-9350-intel/system_files/usr/lib/systemd/user/pipewire.service.d/10-purplefin-dell-ipu7-libcamera.conf
    test -f profile_files/dell-xps-9350-intel/system_files/usr/lib/systemd/user/purplefin-dell-ipu7-v4l2loopback.service
    test -L profile_files/dell-xps-9350-intel/system_files/etc/systemd/user/default.target.wants/purplefin-dell-ipu7-v4l2loopback.service
    test ! -e profile_files/dell-xps-9350-intel/system_files/etc/modules-load.d/purplefin-dell-ipu7.conf
    grep -qF 'purplefin-dell-ipu7-v4l2loopback-load.service' profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/dell-ipu7-setup
    grep -qF '0cab74a6146cdc094e90a408fc608773c350da0f' profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/dell-ipu7-setup
    grep -qF 'ba5db745b26e54abbe459e1a38ff1d22d0fe0caa' profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/dell-ipu7-setup
    grep -qF '32b0d940baaf182a9d01d4833e30bd340d4dc918' profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/dell-ipu7-setup
    test -f profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/dell-ipu7/kernel-evr.denylist
    grep -qF '7.1.2-355.vanilla.fc44' profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/lib/dell-ipu7.sh
    grep -qF 'kernel-staged.pending' profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/lib/dell-ipu7.sh
    grep -qF 'debugfs_create_dir("ipu7-psys", NULL)' profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/dell-ipu7-patch-psys-debugfs
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

    # shellcheck source=/dev/null
    source profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/lib/dell-ipu7.sh
    kernel_denylist="${tmpdir}/ipu7-kernel.denylist"
    ipu7_state_dir="${tmpdir}/ipu7-state"
    : > "${kernel_denylist}"
    export PURPLEFIN_DELL_IPU7_KERNEL_DENYLIST="${kernel_denylist}"
    export PURPLEFIN_DELL_IPU7_STATE_DIR="${ipu7_state_dir}"
    export PURPLEFIN_DELL_IPU7_UNAME_M="x86_64"

    for kernel_release in 7.1.0-100.fc99.x86_64 7.1.9-200.fc99.x86_64; do
        purplefin_dell_ipu7_kernel_supported "${kernel_release}"
    done
    for kernel_release in 6.17.9-200.fc99.x86_64 7.0.0-100.fc99.x86_64 7.0.18-200.fc99.x86_64 7.2.0-100.fc99.x86_64 7.1.0-0.rc1.fc99.x86_64 7.10.0-100.fc99.x86_64; do
        ! purplefin_dell_ipu7_kernel_supported "${kernel_release}"
    done
    selected_kernel="$(printf '%s\n' '7.1.3-400.vanilla.fc44' '7.1.2-355.vanilla.fc44' '7.1.0-0.rc1.fc44' '7.0.18-200.fc44' | purplefin_dell_ipu7_select_kernel_evr)"
    test "${selected_kernel}" = '7.1.2-355.vanilla.fc44'
    export PURPLEFIN_DELL_IPU7_KERNEL_ALLOW_UNPINNED=1
    selected_kernel="$(printf '%s\n' '7.1.3-400.vanilla.fc44' '7.1.2-355.vanilla.fc44' '7.1.0-0.rc1.fc44' | purplefin_dell_ipu7_select_kernel_evr)"
    test "${selected_kernel}" = '7.1.3-400.vanilla.fc44'
    unset PURPLEFIN_DELL_IPU7_KERNEL_ALLOW_UNPINNED
    export PURPLEFIN_DELL_IPU7_KERNEL_EVR=7.1.1-10.vanilla.fc44
    selected_kernel="$(printf '%s\n' '7.1.2-355.vanilla.fc44' '7.1.1-10.vanilla.fc44' | purplefin_dell_ipu7_select_kernel_evr)"
    test "${selected_kernel}" = '7.1.1-10.vanilla.fc44'
    unset PURPLEFIN_DELL_IPU7_KERNEL_EVR
    printf '%s\n' '7.1.2-355.vanilla.fc44' > "${kernel_denylist}"
    if printf '%s\n' '7.1.2-355.vanilla.fc44' | purplefin_dell_ipu7_select_kernel_evr >/dev/null; then
        echo "Dell IPU7 kernel selector accepted a denied pinned kernel" >&2
        exit 1
    fi
    : > "${kernel_denylist}"
    if printf '%s\n' '7.0.18-200.fc99' '7.1.0-0.rc1.fc99' | purplefin_dell_ipu7_select_kernel_evr >/dev/null; then
        echo "Dell IPU7 kernel selector accepted a non-stable-7.1 kernel" >&2
        exit 1
    fi
    repoquery_fixture=$'kernel\t7.1.2-355.vanilla.fc44\tx86_64\nkernel-devel-matched\t7.1.2-355.vanilla.fc44\tnoarch\nkernel-headers\t7.1.2-355.vanilla.fc44\tx86_64'
    package_specs="$(printf '%s\n' "${repoquery_fixture}" | purplefin_dell_ipu7_collect_package_specs_from_repoquery '7.1.2-355.vanilla.fc44' 'x86_64' kernel kernel-devel-matched kernel-headers)"
    grep -qx 'kernel-7.1.2-355.vanilla.fc44.x86_64' <<<"${package_specs}"
    grep -qx 'kernel-devel-matched-7.1.2-355.vanilla.fc44.noarch' <<<"${package_specs}"
    grep -qx 'kernel-headers-7.1.2-355.vanilla.fc44.x86_64' <<<"${package_specs}"
    mismatched_repoquery_fixture=$'kernel\t7.1.2-355.vanilla.fc44\tx86_64\nkernel-headers\t7.1.3-400.vanilla.fc44\tx86_64'
    if printf '%s\n' "${mismatched_repoquery_fixture}" | purplefin_dell_ipu7_collect_package_specs_from_repoquery '7.1.2-355.vanilla.fc44' 'x86_64' kernel kernel-headers >/dev/null; then
        echo "Dell IPU7 package validator accepted mismatched kernel headers" >&2
        exit 1
    fi
    fstab_ok="${tmpdir}/fstab-ok"
    fstab_bad="${tmpdir}/fstab-bad"
    printf '%s\n' 'UUID=abcd /var ext4 defaults 0 0' > "${fstab_ok}"
    printf '%s\n' '# comment' 'UUID=abcd / btrfs subvol=root 0 0' > "${fstab_bad}"
    ! purplefin_dell_ipu7_fstab_has_root_mount_entry "${fstab_ok}"
    purplefin_dell_ipu7_fstab_has_root_mount_entry "${fstab_bad}"
    ipu7_config="${tmpdir}/ipu7-kernel.config"
    printf '%s\n' 'CONFIG_IPU_BRIDGE=m' 'CONFIG_INTEL_SKL_INT3472=y' 'CONFIG_VIDEO_INTEL_IPU7=m' 'CONFIG_VIDEO_OV08X40=m' > "${ipu7_config}"
    purplefin_dell_ipu7_validate_kernel_config_file "${ipu7_config}"
    printf '%s\n' 'CONFIG_IPU_BRIDGE=m' 'CONFIG_INTEL_SKL_INT3472=y' 'CONFIG_VIDEO_INTEL_IPU7=m' > "${ipu7_config}"
    if purplefin_dell_ipu7_validate_kernel_config_file "${ipu7_config}" >/dev/null 2>&1; then
        echo "Dell IPU7 kernel config validator accepted a missing OV08X40 sensor driver" >&2
        exit 1
    fi
    rm -rf "${ipu7_state_dir}"
    export PURPLEFIN_DELL_IPU7_UNAME_R="7.1.2-355.vanilla.fc44.x86_64"
    purplefin_dell_ipu7_record_kernel_staged '7.1.2-355.vanilla.fc44' '7.1.2-355.vanilla.fc44.x86_64' 'kernel-devel-7.1.2-355.vanilla.fc44.x86_64'
    purplefin_dell_ipu7_assert_booted_kernel
    test -f "${ipu7_state_dir}/kernel-booted.ok"
    test ! -e "${ipu7_state_dir}/kernel-staged.pending"
    rm -rf "${ipu7_state_dir}"
    purplefin_dell_ipu7_record_kernel_staged '7.1.2-355.vanilla.fc44' '7.1.2-355.vanilla.fc44.x86_64'
    export PURPLEFIN_DELL_IPU7_UNAME_R="7.0.11-200.fc44.x86_64"
    if purplefin_dell_ipu7_assert_booted_kernel >/dev/null 2>&1; then
        echo "Dell IPU7 marker gate accepted rollback from staged kernel" >&2
        exit 1
    fi
    unset PURPLEFIN_DELL_IPU7_UNAME_R

    psys_patcher="profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/dell-ipu7-patch-psys-debugfs"
    old_psys_line=$'\tdir = debugfs_create_dir("psys", psys->adev->isp->ipu7_dir);'
    new_psys_line=$'\tdir = debugfs_create_dir("ipu7-psys", NULL);'
    printf '%s\n' 'static int ipu7_psys_init_debugfs(void)' "${old_psys_line}" > "${ipu7_psys_tmp}"
    "${psys_patcher}" "${ipu7_psys_tmp}" >/dev/null 2>&1
    grep -Fqx "${new_psys_line}" "${ipu7_psys_tmp}"
    printf '%s\n' 'dir = debugfs_create_dir("psys", NULL);' > "${ipu7_psys_tmp}"
    if "${psys_patcher}" "${ipu7_psys_tmp}" >/dev/null 2>&1; then
        echo "PSYS patcher accepted an unexpected upstream debugfs line" >&2
        exit 1
    fi

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
