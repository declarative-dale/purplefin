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

The Dell profile also accepts build-time kernel canary arguments:

```bash
podman build \
  --build-arg BUILD_PROFILE=dell-xps-9350-intel \
  --build-arg PURPLEFIN_DELL_IPU7_KERNEL_EVR=7.1.2-355.vanilla.fc44 \
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

IPU7 setup requires a validated mainline Linux `7.1.x` kernel. Release
candidates and other kernel series, including `7.0.x`, are rejected. The Dell
profile bakes the pinned kernel EVR `7.1.2-355.vanilla.fc44` into the image at
build time instead of replacing the kernel on first boot. Tested replacements
can be selected with the `PURPLEFIN_DELL_IPU7_KERNEL_EVR` build arg; moving to
the newest available stable `7.1.x` kernel requires the explicit
`PURPLEFIN_DELL_IPU7_KERNEL_ALLOW_UNPINNED=1` canary build arg. Exact EVRs can
be blocked in `/usr/share/purplefin/dell-ipu7/kernel-evr.denylist`.

During the Dell image build, Purplefin enables the Dell-only mainline kernel
source, verifies that the kernel runtime packages, `kernel-devel`,
`kernel-devel-matched`, and `kernel-headers` all exist for the same EVR and
architecture, checks the target kernel config for required IPU7 support, installs
the validated runtime kernel packages, and removes inherited runtime kernels so
bootc selects the baked Dell kernel.

The flow is:

1. The Dell profile build writes the Dell-only mainline kernel repo, bakes the
   pinned Linux `7.1.x` runtime kernel packages into the image, prunes inherited
   runtime kernels, and records exact build package specs in
   `/usr/share/purplefin/dell-ipu7/kernel-build-packages`.
2. On first boot, `20-dell-ipu7-stable-kernel` validates that the system booted
   the baked Linux `7.1.x` kernel and records
   `/var/lib/purplefin/dell-ipu7/kernel-booted.ok`.
3. `30-dell-ipu7-build-deps` layers DKMS, clang/LLVM, exact kernel
   headers/devel packages for the validated kernel, libcamera, PipeWire,
   GStreamer, and `akmod-v4l2loopback` fallback support.
4. Reboot into that dependency deployment.
5. `40-dell-ipu7-dkms-userspace` clones
   `https://github.com/jibsta210/ipu7-camera-linux.git` at
   `0cab74a6146cdc094e90a408fc608773c350da0f`, `intel/ipu7-drivers` at
   `ba5db745b26e54abbe459e1a38ff1d22d0fe0caa`, and libcamera at
   `32b0d940baaf182a9d01d4833e30bd340d4dc918`. It installs module ordering and
   `/dev/video33` v4l2loopback config, builds `intel_cvs` with DKMS for the
   booted kernel only, builds a patched `intel_ipu7_psys` DKMS module, probes
   both modules, installs an IPU7-enabled libcamera build under `/usr/local`,
   and enables real-root services for the IPU7 PSYS and v4l2loopback fallback
   modules.

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
cat /var/lib/purplefin/dell-ipu7/kernel-booted.ok
dkms status
sudo modprobe intel_cvs
sudo modprobe intel_ipu7_psys
journalctl -k -b | grep -Ei 'ipu7|psys|lookup_noperm_common|firmware'
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
- Vates planet boot, Plymouth, GDM login, and legacy Bluefin logo-path branding over the inherited Bluefin/Fedora assets.
- Dell XPS 9350 Intel 1Password RPM repo plus baked `1password-cli`.
- Dell XPS 9350 Intel first-boot rpm-ostree task that layers the 1Password desktop RPM on installed systems. The desktop RPM writes under `/opt`, which is supported by rpm-ostree layering on the target host but fails during direct bootc container package installation.
- Dell XPS 9350 Intel image-baked, pinned, validated mainline Linux `7.1.x` kernel plus first-boot IPU7 camera setup with DKMS `intel_cvs`, patched `intel_ipu7_psys`, IPU7 libcamera under `/usr/local`, PipeWire environment drop-in, and `/dev/video33` fallback service.
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
