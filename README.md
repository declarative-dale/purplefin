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
| `dell-xps-9350-intel` | Dell XPS 9350 Intel profile with Goodix fingerprint auth, 1Password integration, rEFInd theming, and optional PAM U2F support for security keys. |

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

The `latest` tag tracks the generic profile. Use the `dell-xps-9350-intel`
tag for the Dell profile. The Dell profile bakes in `1password-cli`; the
1Password desktop RPM is layered by a first-boot rpm-ostree task and becomes
available after the reboot into that staged deployment.

## What Is Tracked

- Base image selection and build profile logic.
- A centralized first-boot rpm-ostree runner with ordered task scripts and `/var/lib/purplefin/firstboot/*.done` markers. It stops after a task stages a deployment so later rpm-ostree tasks run after the next reboot instead of replacing earlier queued changes.
- System Flatpak preinstall manifest generated from this laptop.
- Homebrew `Brewfile` generated from this laptop.
- A first-boot, idempotent Homebrew bundle service.
- Vates planet boot and GDM login branding over the inherited Bluefin/Fedora boot/login logo assets.
- Dell XPS 9350 Intel 1Password RPM repo plus baked `1password-cli`.
- Dell XPS 9350 Intel first-boot rpm-ostree task that layers the 1Password desktop RPM on installed systems. The desktop RPM writes under `/opt`, which is supported by rpm-ostree layering on the target host but fails during direct bootc container package installation.
- Dell XPS 9350 Intel profile files for fingerprint auth.
- Dell XPS 9350 Intel rEFInd Regular Dark theme staging plus an idempotent boot-time installer that enables it when `/boot/efi/EFI/refind/refind.conf` is present.
- Dell XPS 9350 Intel optional PAM U2F support for security keys. User-specific key mappings are not included; register a key after switching with `pamu2fcfg > ~/.config/Yubico/u2f_keys`.

## What Is Not Tracked

This public repo intentionally excludes credentials, biometric enrollments,
SSH/GPG keys, machine identity, private dotfiles, and user-specific systemd
control files.

## Development Checks

```bash
just check
```
