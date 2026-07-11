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
    install -d "${tmpdir}/usr/bin" "${tmpdir}/usr/sbin"
    printf '%s\n' '#!/usr/bin/env sh' 'exit 0' > "${tmpdir}/usr/bin/true"
    cp "${tmpdir}/usr/bin/true" "${tmpdir}/usr/sbin/modprobe"
    chmod 0755 "${tmpdir}/usr/bin/true" "${tmpdir}/usr/sbin/modprobe"
    printf '%s\n' '[Unit]' 'Description=System Initialization' > "${tmpdir}/usr/lib/systemd/system/sysinit.target"
    printf '%s\n' '[Unit]' 'Description=Local File Systems' > "${tmpdir}/usr/lib/systemd/system/local-fs.target"
    printf '%s\n' '[Unit]' 'Description=Basic System' 'Requires=sysinit.target' 'After=sysinit.target' > "${tmpdir}/usr/lib/systemd/system/basic.target"
    printf '%s\n' '[Unit]' 'Description=Multi-User System' 'Requires=basic.target' 'After=basic.target' > "${tmpdir}/usr/lib/systemd/system/multi-user.target"
    printf '%s\n' '[Unit]' 'Description=udev settle stub' '[Service]' 'Type=oneshot' 'ExecStart=/usr/bin/true' > "${tmpdir}/usr/lib/systemd/system/systemd-udev-settle.service"
    printf '%s\n' '[Unit]' 'Description=module loader stub' '[Service]' 'Type=oneshot' 'ExecStart=/usr/bin/true' > "${tmpdir}/usr/lib/systemd/system/systemd-modules-load.service"
    printf '%s\n' '[Unit]' 'Description=display manager stub' '[Service]' 'Type=oneshot' 'ExecStart=/usr/bin/true' > "${tmpdir}/usr/lib/systemd/system/display-manager.service"
    systemd-analyze verify --root="${tmpdir}" /usr/lib/systemd/system/purplefin-firstboot-rpm-ostree.service /usr/lib/systemd/system/purplefin-brew-bundle.service /usr/lib/systemd/system/purplefin-refind-theme.service /usr/lib/systemd/system/purplefin-dell-ipu7-camera.service
    udevadm verify --root="${tmpdir}" /usr/lib/udev/rules.d/99-purplefin-dell-ipu7-camera.rules

    test -f manifests/Brewfile
    test -f manifests/flatpaks.preinstall
    ! grep -qF 'com.bitwarden.desktop' manifests/flatpaks.preinstall
    test ! -e system_files/usr/libexec/purplefin/install-bitwarden-cli-native
    test -x system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/05-bitwarden-desktop-layer
    grep -qF 'app=desktop&platform=linux&variant=rpm' system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/05-bitwarden-desktop-layer
    grep -qF 'rpm -q bitwarden' system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/05-bitwarden-desktop-layer
    grep -qF "rpm -qp --qf '%{NAME}\\n'" system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/05-bitwarden-desktop-layer
    grep -qF 'run_rpm_ostree install --idempotent "${desktop_rpm}"' system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/05-bitwarden-desktop-layer
    test -x build_files/install-bitwarden-cli-rpm.sh
    test -f build_files/bitwarden-cli.spec
    grep -qF 'https://vault.bitwarden.com/download/?app=cli&platform=linux' build_files/install-bitwarden-cli-rpm.sh
    grep -qF 'rpmbuild -bb' build_files/install-bitwarden-cli-rpm.sh
    grep -qF 'Name:           purplefin-bitwarden-cli' build_files/bitwarden-cli.spec
    grep -qF '%global __os_install_post %{nil}' build_files/bitwarden-cli.spec
    grep -qF 'bash /tmp/purplefin-build/install-bitwarden-cli-rpm.sh' build_files/build.sh
    grep -qF 'rpm -q purplefin-bitwarden-cli' build_files/build.sh
    grep -qF "rpm -qf --qf '%{NAME}\\n' /usr/bin/bw" build_files/build.sh
    for package in nm-connection-editor nm-connection-editor-desktop wireguard-tools; do
        grep -qE "^[[:space:]]*${package}$" build_files/build.sh
    done
    grep -qF 'dnf5 -y install "${base_packages[@]}"' build_files/build.sh
    grep -qF 'for command in nm-connection-editor wg' build_files/build.sh
    grep -qF 'test -f /usr/share/applications/nm-connection-editor.desktop' build_files/build.sh
    grep -qF 'systemctl disable tailscaled.service' build_files/build.sh
    grep -qF 'dnf5 -y remove --no-autoremove tailscale' build_files/build.sh
    grep -qF 'rm -f /etc/yum.repos.d/tailscale.repo' build_files/build.sh
    grep -qF 'rm -f /usr/share/ublue-os/privileged-setup.hooks.d/10-tailscale.sh' build_files/build.sh
    grep -qF "sed -i '/^\\[tailscale-stable\\]$/,+1d'" build_files/build.sh
    grep -qF "sed -i '/^Tailscale is included,/d'" build_files/build.sh
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
    grep -qx 'excludepkgs=1password\*,bitwarden\*' system_files/etc/yum.repos.d/terra.repo
    test -f system_files/etc/yum.repos.d/hashicorp.repo
    grep -qx '\[hashicorp\]' system_files/etc/yum.repos.d/hashicorp.repo
    grep -qx 'baseurl=https://rpm.releases.hashicorp.com/fedora/\$releasever/\$basearch/stable' system_files/etc/yum.repos.d/hashicorp.repo
    grep -qx 'gpgkey=https://rpm.releases.hashicorp.com/gpg' system_files/etc/yum.repos.d/hashicorp.repo
    for package in ansible openbao opentofu packer; do
        grep -qE "^[[:space:]]*${package}$" build_files/build.sh
    done
    grep -qF 'dnf5 -y install "${infrastructure_packages[@]}"' build_files/build.sh
    grep -qF 'for command in ansible bao packer tofu' build_files/build.sh
    test -f system_files/usr/lib/tmpfiles.d/purplefin-openbao.conf
    grep -qx 'd /var/lib/openbao 0700 openbao openbao - -' system_files/usr/lib/tmpfiles.d/purplefin-openbao.conf
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
    grep -qF 'PURPLEFIN_DELL_MAINLINE_KERNEL_EVR' Containerfile
    grep -qF 'PURPLEFIN_DELL_MAINLINE_KERNEL_ALLOW_UNPINNED' Containerfile
    ! grep -qF 'dracut --force "${kernel_modules_dir}/initramfs.img" "${kernel_version}"' build_files/build.sh
    grep -qF 'rm -f /boot/symvers-*.xz' build_files/build.sh
    grep -qF '/var/lib/rpm-state' build_files/build.sh
    grep -qF '/var/log/dnf5.log*' build_files/build.sh
    test -x system_files/usr/libexec/purplefin/run-firstboot-rpm-ostree
    test -z "$(find system_files -iname '*ipu7*' -print -quit)"
    test -z "$(find system_files -iname '*librepods*' -print -quit)"
    test -x build_files/profiles/dell-xps-9350-intel-no-ipu7.sh
    grep -qF 'copy_profile_file "etc/yum.repos.d/1password.repo"' build_files/profiles/dell-xps-9350-intel-no-ipu7.sh
    grep -qF 'copy_profile_file "usr/libexec/purplefin/firstboot-rpm-ostree.d/10-1password-desktop-layer"' build_files/profiles/dell-xps-9350-intel-no-ipu7.sh
    grep -qF 'copy_profile_file "usr/libexec/purplefin/install-librepods"' build_files/profiles/dell-xps-9350-intel-no-ipu7.sh
    grep -qF 'copy_profile_tree "usr/libexec/purplefin/librepods"' build_files/profiles/dell-xps-9350-intel-no-ipu7.sh
    grep -qF 'copy_profile_tree "usr/share/purplefin/refind"' build_files/profiles/dell-xps-9350-intel-no-ipu7.sh
    grep -qF '/usr/libexec/purplefin/install-librepods' build_files/profiles/dell-xps-9350-intel-no-ipu7.sh
    grep -qF 'install_mainline_7_1_kernel' build_files/profiles/dell-xps-9350-intel-no-ipu7.sh
    grep -qF 'kernel_default_evr="7.1.2-355.vanilla.fc44"' build_files/profiles/dell-xps-9350-intel-no-ipu7.sh
    grep -qF 'remove_inherited_v4l2loopback_kmods' build_files/profiles/dell-xps-9350-intel-no-ipu7.sh
    ! grep -Eq 'copy_profile_(file|tree) ".*(dell-ipu7|ipu7-|v4l2loopback|libcamera|pipewire|intel_cvs|intel_ipu7)' build_files/profiles/dell-xps-9350-intel-no-ipu7.sh
    ! grep -Eq '20-dell-ipu7|30-dell-ipu7|40-dell-ipu7|dell-ipu7-setup|dell-ipu7-patch|usr/libexec/purplefin/lib/dell-ipu7|purplefin-dell-ipu7-(psys|v4l2loopback)' build_files/profiles/dell-xps-9350-intel-no-ipu7.sh
    test ! -e system_files/etc/yum.repos.d/1password.repo
    test ! -e system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/10-1password-desktop-layer
    test -f profile_files/dell-xps-9350-intel/system_files/etc/yum.repos.d/1password.repo
    test ! -e profile_files/dell-xps-9350-intel/system_files/etc/plymouth
    test -x profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/10-1password-desktop-layer
    test -x profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/20-dell-ipu7-stable-kernel
    test -x profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/dell-ipu7-activate
    test -x profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/dell-ipu7-rebind-sensor
    test -x profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/install-librepods
    test -x profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/librepods/librepods
    test -f profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/librepods/librepods.sha256
    test -f profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/librepods.provenance
    (cd profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/librepods && sha256sum -c librepods.sha256)
    grep -qF 'source_run_id=25080113527' profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/librepods.provenance
    grep -qF 'source_artifact=librepods' profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/librepods.provenance
    grep -qF '/usr/libexec/purplefin/install-librepods' build_files/profiles/dell-xps-9350-intel.sh
    test -f profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/lib/dell-ipu7.sh
    grep -qF 'install_ipu7_kernel' build_files/profiles/dell-xps-9350-intel.sh
    grep -qF 'remove_non_ipu7_runtime_kernels' build_files/profiles/dell-xps-9350-intel.sh
    grep -qF 'remove_inherited_v4l2loopback_kmods' build_files/profiles/dell-xps-9350-intel.sh
    grep -qF 'kernel-build-packages' build_files/profiles/dell-xps-9350-intel.sh
    grep -qF 'https://github.com/intel/vision-drivers.git' build_files/profiles/dell-xps-9350-intel.sh
    grep -qF '845d6f8bdf66ff1f455901da9de5e00a53a83dce' build_files/profiles/dell-xps-9350-intel.sh
    grep -qF 'KERNEL_SRC="/usr/lib/modules/${target_release}/build"' build_files/profiles/dell-xps-9350-intel.sh
    grep -qF '/updates/purplefin/intel_cvs.ko' build_files/profiles/dell-xps-9350-intel.sh
    grep -qF 'ipu7_fw.bin${suffix}' build_files/profiles/dell-xps-9350-intel.sh
    grep -qF 'kernel-devel-matched-${target_evr}.${target_arch}' build_files/profiles/dell-xps-9350-intel.sh
    grep -qF 'dnf5 -y remove --no-autoremove "${cleanup_packages[@]}"' build_files/profiles/dell-xps-9350-intel.sh
    for package in libcamera libcamera-ipa libcamera-tools pipewire-plugin-libcamera; do
        grep -qE "^[[:space:]]*${package}$" build_files/profiles/dell-xps-9350-intel.sh
    done
    ! grep -qF 'override replace' profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/20-dell-ipu7-stable-kernel
    test -f profile_files/dell-xps-9350-intel/system_files/usr/lib/systemd/system/purplefin-dell-ipu7-camera.service
    test -f profile_files/dell-xps-9350-intel/system_files/usr/lib/udev/rules.d/99-purplefin-dell-ipu7-camera.rules
    test -f profile_files/dell-xps-9350-intel/system_files/usr/lib/modprobe.d/purplefin-dell-ipu7.conf
    test -f profile_files/dell-xps-9350-intel/system_files/usr/lib/modules-load.d/purplefin-dell-ipu7.conf
    test -f profile_files/dell-xps-9350-intel/system_files/usr/share/wireplumber/wireplumber.conf.d/50-purplefin-dell-ipu7.conf
    grep -qF 'ACTION=="bind", SUBSYSTEM=="i2c", DRIVER=="Intel CVS driver"' profile_files/dell-xps-9350-intel/system_files/usr/lib/udev/rules.d/99-purplefin-dell-ipu7-camera.rules
    grep -qF 'i2c-OVTI02C1:00' profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/dell-ipu7-rebind-sensor
    grep -qF 'softdep ov02c10 pre: intel_cvs' profile_files/dell-xps-9350-intel/system_files/usr/lib/modprobe.d/purplefin-dell-ipu7.conf
    grep -qF 'monitor.v4l2.rules' profile_files/dell-xps-9350-intel/system_files/usr/share/wireplumber/wireplumber.conf.d/50-purplefin-dell-ipu7.conf
    grep -qF 'device.description = "ipu7"' profile_files/dell-xps-9350-intel/system_files/usr/share/wireplumber/wireplumber.conf.d/50-purplefin-dell-ipu7.conf
    grep -qF 'device.disabled = true' profile_files/dell-xps-9350-intel/system_files/usr/share/wireplumber/wireplumber.conf.d/50-purplefin-dell-ipu7.conf
    spa-json-dump profile_files/dell-xps-9350-intel/system_files/usr/share/wireplumber/wireplumber.conf.d/50-purplefin-dell-ipu7.conf >/dev/null
    for obsolete in \
        usr/libexec/purplefin/dell-ipu7-setup \
        usr/libexec/purplefin/dell-ipu7-patch-psys-debugfs \
        usr/libexec/purplefin/firstboot-rpm-ostree.d/30-dell-ipu7-build-deps \
        usr/libexec/purplefin/firstboot-rpm-ostree.d/40-dell-ipu7-dkms-userspace \
        usr/lib/systemd/system/purplefin-dell-ipu7-psys-load.service \
        usr/lib/systemd/system/purplefin-dell-ipu7-v4l2loopback-load.service \
        usr/lib/systemd/user/pipewire.service.d/10-purplefin-dell-ipu7-libcamera.conf \
        usr/lib/systemd/user/purplefin-dell-ipu7-v4l2loopback.service \
        etc/systemd/user/default.target.wants/purplefin-dell-ipu7-v4l2loopback.service; do
        test ! -e "profile_files/dell-xps-9350-intel/system_files/${obsolete}"
    done
    ! rg -q '0cab74a6146cdc094e90a408fc608773c350da0f|ba5db745b26e54abbe459e1a38ff1d22d0fe0caa|32b0d940baaf182a9d01d4833e30bd340d4dc918|OV08X40|intel_ipu7_psys' profile_files/dell-xps-9350-intel/system_files build_files/profiles/dell-xps-9350-intel.sh
    test -f profile_files/dell-xps-9350-intel/system_files/usr/share/purplefin/dell-ipu7/kernel-evr.denylist
    grep -qF '7.1.2-355.vanilla.fc44' profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/lib/dell-ipu7.sh
    grep -qF 'kernel-staged.pending' profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/lib/dell-ipu7.sh
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
    repoquery_fixture=$'kernel\t7.1.2-355.vanilla.fc44\tx86_64\nkernel-devel\t7.1.2-355.vanilla.fc44\tx86_64'
    package_specs="$(printf '%s\n' "${repoquery_fixture}" | purplefin_dell_ipu7_collect_package_specs_from_repoquery '7.1.2-355.vanilla.fc44' 'x86_64' kernel kernel-devel)"
    grep -qx 'kernel-7.1.2-355.vanilla.fc44.x86_64' <<<"${package_specs}"
    grep -qx 'kernel-devel-7.1.2-355.vanilla.fc44.x86_64' <<<"${package_specs}"
    mismatched_repoquery_fixture=$'kernel\t7.1.2-355.vanilla.fc44\tx86_64\nkernel-devel\t7.1.3-400.vanilla.fc44\tx86_64'
    if printf '%s\n' "${mismatched_repoquery_fixture}" | purplefin_dell_ipu7_collect_package_specs_from_repoquery '7.1.2-355.vanilla.fc44' 'x86_64' kernel kernel-devel >/dev/null; then
        echo "Dell IPU7 package validator accepted mismatched kernel-devel" >&2
        exit 1
    fi
    fstab_ok="${tmpdir}/fstab-ok"
    fstab_bad="${tmpdir}/fstab-bad"
    printf '%s\n' 'UUID=abcd /var ext4 defaults 0 0' > "${fstab_ok}"
    printf '%s\n' '# comment' 'UUID=abcd / btrfs subvol=root 0 0' > "${fstab_bad}"
    ! purplefin_dell_ipu7_fstab_has_root_mount_entry "${fstab_ok}"
    purplefin_dell_ipu7_fstab_has_root_mount_entry "${fstab_bad}"
    ipu7_config="${tmpdir}/ipu7-kernel.config"
    required_ipu7_configs=(CONFIG_IPU_BRIDGE CONFIG_VIDEO_INTEL_IPU7 CONFIG_VIDEO_OV02C10 CONFIG_USB_USBIO CONFIG_GPIO_USBIO CONFIG_I2C_USBIO)
    printf '%s=m\n' "${required_ipu7_configs[@]}" > "${ipu7_config}"
    purplefin_dell_ipu7_validate_kernel_config_file "${ipu7_config}"
    for missing_config in "${required_ipu7_configs[@]}"; do
        grep -v "^${missing_config}=" "${ipu7_config}" > "${ipu7_config}.missing"
        if purplefin_dell_ipu7_validate_kernel_config_file "${ipu7_config}.missing" >/dev/null 2>&1; then
            echo "Dell IPU7 kernel config validator accepted missing ${missing_config}" >&2
            exit 1
        fi
    done
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

    fake_sysfs="${tmpdir}/fake-sys"
    fake_sensor="${fake_sysfs}/bus/i2c/devices/i2c-OVTI02C1:00"
    fake_driver="${fake_sysfs}/bus/i2c/drivers/ov02c10"
    mkdir -p "${fake_sensor}" "${fake_driver}"
    : > "${fake_driver}/bind"
    ln -s ../../drivers/ov02c10 "${fake_sensor}/driver"
    PURPLEFIN_DELL_IPU7_SYSFS_ROOT="${fake_sysfs}" profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/dell-ipu7-rebind-sensor
    rm "${fake_sensor}/driver"
    if PURPLEFIN_DELL_IPU7_SYSFS_ROOT="${fake_sysfs}" profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/dell-ipu7-rebind-sensor >/dev/null 2>&1; then
        echo "Dell IPU7 sensor helper accepted a bind that did not attach ov02c10" >&2
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

build-dell-no-ipu7:
    podman build --build-arg BUILD_PROFILE=dell-xps-9350-intel-no-ipu7 --tag {{image}}:dell-xps-9350-intel-no-ipu7 .

lint-generic:
    podman run --rm --entrypoint bootc {{image}}:generic-x86_64 container lint

lint-dell:
    podman run --rm --entrypoint bootc {{image}}:dell-xps-9350-intel container lint

lint-dell-no-ipu7:
    podman run --rm --entrypoint bootc {{image}}:dell-xps-9350-intel-no-ipu7 container lint
