image := "ghcr.io/declarative-dale/purplefin"

default:
    @just --list

check:
    #!/usr/bin/env bash
    set -euo pipefail

    find build_files system_files/usr/libexec/purplefin profile_files -type f \( -name '*.sh' -o -perm -111 \) -exec bash -n {} +

    tmpdir="$(mktemp -d)"
    trap 'rm -rf "${tmpdir}"' EXIT
    cp -a system_files/. "${tmpdir}/"
    install -d "${tmpdir}/usr/lib/systemd/system"
    printf '%s\n' '[Unit]' 'Description=System Initialization' > "${tmpdir}/usr/lib/systemd/system/sysinit.target"
    printf '%s\n' '[Unit]' 'Description=Basic System' 'Requires=sysinit.target' 'After=sysinit.target' > "${tmpdir}/usr/lib/systemd/system/basic.target"
    printf '%s\n' '[Unit]' 'Description=Multi-User System' 'Requires=basic.target' 'After=basic.target' > "${tmpdir}/usr/lib/systemd/system/multi-user.target"
    systemd-analyze verify --root="${tmpdir}" /usr/lib/systemd/system/purplefin-firstboot-rpm-ostree.service /usr/lib/systemd/system/purplefin-brew-bundle.service

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
    test -x system_files/usr/libexec/purplefin/run-firstboot-rpm-ostree
    test ! -e system_files/etc/yum.repos.d/1password.repo
    test ! -e system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/10-1password-desktop-layer
    test -f profile_files/dell-xps-9350-intel/system_files/etc/yum.repos.d/1password.repo
    test ! -e profile_files/dell-xps-9350-intel/system_files/etc/plymouth
    test -x profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/10-1password-desktop-layer
    test ! -e profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/firstboot-rpm-ostree.d/50-dell-vates-plymouth-initramfs

build-generic:
    podman build --build-arg BUILD_PROFILE=generic-x86_64 --tag {{image}}:generic-x86_64 .

build-dell:
    podman build --build-arg BUILD_PROFILE=dell-xps-9350-intel --tag {{image}}:dell-xps-9350-intel .

lint-generic:
    podman run --rm --entrypoint bootc {{image}}:generic-x86_64 container lint

lint-dell:
    podman run --rm --entrypoint bootc {{image}}:dell-xps-9350-intel container lint
