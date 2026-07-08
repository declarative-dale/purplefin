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
| `dell-xps-9350-intel` | Dell XPS 9350 Intel profile with Goodix fingerprint auth, 1Password integration, rEFInd theming, Dell-only IPU7 camera setup, and optional PAM U2F support for security keys. |

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

## Dell IPU7 Camera Flow

The Dell XPS 9350 Intel profile includes Dell-only first-boot tasks for IPU7
camera support. The generic profile does not install IPU7 repositories,
services, module configs, or setup scripts.

IPU7 setup requires a stable mainline Linux `7.1.x` kernel. Release candidates
and other kernel series, including `7.0.x`, are rejected. The first Dell IPU7
task enables a stable mainline kernel source for the Dell profile and stages a
Linux `7.1.x` kernel. Later tasks run only after the system has rebooted into
that supported kernel.

The staged flow is:

1. `20-dell-ipu7-stable-kernel` writes the Dell-only mainline kernel repo and
   stages the Linux `7.1.x` kernel override.
2. Reboot into the staged kernel deployment.
3. `30-dell-ipu7-build-deps` layers DKMS, clang/LLVM, kernel headers/devel,
   libcamera, PipeWire, GStreamer, and `v4l2loopback` build dependencies.
4. Reboot into that dependency deployment.
5. `40-dell-ipu7-dkms-userspace` clones
   `https://github.com/jibsta210/ipu7-camera-linux.git` at
   `0cab74a6146cdc094e90a408fc608773c350da0f`, installs module ordering and
   `/dev/video33` v4l2loopback config, builds `intel_cvs` with DKMS, builds a
   patched `intel_ipu7_psys` DKMS module, and installs an IPU7-enabled
   libcamera build under `/usr/local`.

The PSYS DKMS build applies a one-line debugfs fix before compiling:

```c
dir = debugfs_create_dir("ipu7-psys", NULL);
```

The patcher refuses to continue unless the upstream Intel source still
contains the expected old line:

```c
dir = debugfs_create_dir("psys", psys->adev->isp->ipu7_dir);
```

That guard is intentional. The old parent-pointer form can fault in debugfs
lookup paths such as `lookup_noperm_common` when the PSYS struct layout no
longer matches the running kernel.

Intel documents IPU7 firmware and proprietary support libraries in
`https://github.com/intel/ipu7-camera-bins`. Purplefin does not copy those
files into `/usr/lib/firmware` from first boot because `/usr` is managed by
rpm-ostree. If firmware is not already provided by the image or a layered
package, the Dell IPU7 setup fails clearly before building the hardware path.

Runtime verification on the Dell laptop:

```bash
uname -r
dkms status
sudo modprobe intel_cvs
sudo modprobe intel_ipu7_psys
journalctl -k -b | grep -Ei 'ipu7|psys|lookup_noperm_common'
ls -l /dev/ipu7-psys0 /dev/video33
cam -l
```

Browsers should see the camera through PipeWire after the custom libcamera
build is active. A user fallback service is also provided for a
`libcamerasrc ! videoconvert ! videoflip ! v4l2sink device=/dev/video33`
path when `/dev/ipu7-psys0` is absent.

## What Is Tracked

- Base image selection and build profile logic.
- A centralized first-boot rpm-ostree runner with ordered task scripts and `/var/lib/purplefin/firstboot/*.done` markers. It stops after a task stages a deployment so later rpm-ostree tasks run after the next reboot instead of replacing earlier queued changes.
- System Flatpak preinstall manifest generated from this laptop.
- Homebrew `Brewfile` generated from this laptop.
- A first-boot, idempotent Homebrew bundle service.
- Vates planet boot, initramfs, GDM login, and legacy Bluefin logo-path branding over the inherited Bluefin/Fedora assets.
- Dell XPS 9350 Intel 1Password RPM repo plus baked `1password-cli`.
- Dell XPS 9350 Intel first-boot rpm-ostree task that layers the 1Password desktop RPM on installed systems. The desktop RPM writes under `/opt`, which is supported by rpm-ostree layering on the target host but fails during direct bootc container package installation.
- Dell XPS 9350 Intel first-boot IPU7 camera setup gated to stable mainline Linux `7.1.x`, with DKMS `intel_cvs`, patched `intel_ipu7_psys`, IPU7 libcamera under `/usr/local`, PipeWire environment drop-in, and `/dev/video33` fallback service.
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
