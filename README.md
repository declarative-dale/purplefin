# Purplefin

Purplefin is a custom Universal Blue image based on Bluefin:

```text
ghcr.io/ublue-os/bluefin:stable
```

The image is built from this repository and published to:

```text
ghcr.io/declarative-dale/purplefin
```

## Profiles

Build-time profiles keep generic public image customizations separate from
laptop-specific hardware behavior.

| Profile | Purpose |
| --- | --- |
| `generic-x86_64` | Common public x86_64 image with Purplefin packages, Flatpak preinstalls, and Homebrew bundle setup. |
| `dell-xps-9350-intel` | Dell XPS 9350 Intel profile with Goodix fingerprint auth and the local Bluefin/refind Plymouth payload. It also enables a target-host service to track those Plymouth files into the initramfs after first boot. |

The default profile is `generic-x86_64`.

## Build Locally

```bash
just build-generic
just build-dell
```

Or select a profile directly:

```bash
podman build \
  --build-arg BUILD_PROFILE=dell-xps-9350-intel \
  --tag ghcr.io/declarative-dale/purplefin:dell-xps-9350-intel \
  .
```

## Switch To The Image

Generic profile:

```bash
sudo bootc switch ghcr.io/declarative-dale/purplefin:generic-x86_64
```

Dell XPS 9350 Intel profile:

```bash
sudo bootc switch ghcr.io/declarative-dale/purplefin:dell-xps-9350-intel
```

Reboot after switching.

## What Is Tracked

- Base image selection and build profile logic.
- 1Password RPM repo plus baked `1password-cli`.
- An enabled first-boot service that layers the 1Password desktop RPM on installed systems. The desktop RPM writes under `/opt`, which is supported by rpm-ostree layering on the target host but fails during direct bootc container package installation.
- System Flatpak preinstall manifest generated from this laptop.
- Homebrew `Brewfile` generated from this laptop.
- A first-boot, idempotent Homebrew bundle service.
- Dell XPS 9350 Intel profile files for fingerprint auth and Plymouth/refind initramfs customization.
- Dell XPS 9350 Intel first-boot service to run `rpm-ostree initramfs-etc` on the installed host, because that command cannot run inside a container build.

## What Is Not Tracked

This public repo intentionally excludes credentials, biometric enrollments,
SSH/GPG keys, machine identity, private dotfiles, and user-specific systemd
control files.

## Development Checks

```bash
just check
```
