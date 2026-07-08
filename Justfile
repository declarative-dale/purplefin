image := "ghcr.io/declarative-dale/purplefin"

default:
    @just --list

check:
    bash -n build_files/build.sh build_files/profiles/*.sh system_files/usr/libexec/purplefin/* profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/*
    test -f manifests/Brewfile
    test -f manifests/flatpaks.preinstall
    test -f profile_files/dell-xps-9350-intel/system_files/etc/plymouth/plymouthd.conf

build-generic:
    podman build --build-arg BUILD_PROFILE=generic-x86_64 --tag {{image}}:generic-x86_64 .

build-dell:
    podman build --build-arg BUILD_PROFILE=dell-xps-9350-intel --tag {{image}}:dell-xps-9350-intel .

lint-generic:
    podman run --rm --entrypoint bootc {{image}}:generic-x86_64 container lint

lint-dell:
    podman run --rm --entrypoint bootc {{image}}:dell-xps-9350-intel container lint
