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
| `dell-xps-9350-intel-no-ipu7` | Dell XPS 9350 Intel test profile with the same pinned mainline `7.1.x` kernel and non-camera laptop setup as the Dell profile, but without the IPU7 camera module, activation rules, or camera userspace. |

The default profile is `generic-x86_64`.

## Build Locally

```bash
just build-generic
just build-dell
just build-dell-no-ipu7
```

The `just` targets inspect Bluefin's `ostree.linux` label and write the matching
kernel label into the derived image. For an equivalent direct build, resolve
that value first:

```bash
base_kernel="$(skopeo inspect docker://ghcr.io/ublue-os/bluefin:stable | jq -er '.Labels["ostree.linux"]')"
target_kernel="$(build_files/select-ostree-linux.sh dell-xps-9350-intel "${base_kernel}")"
podman build \
  --build-arg BUILD_PROFILE=dell-xps-9350-intel \
  --build-arg PURPLEFIN_OSTREE_LINUX="${target_kernel}" \
  --label "ostree.linux=${target_kernel}" \
  --tag ghcr.io/declarative-dale/purplefin:dell-xps-9350-intel \
  .
```

The Dell profile also accepts build-time kernel canary arguments:

```bash
podman build \
  --build-arg BUILD_PROFILE=dell-xps-9350-intel \
  --build-arg PURPLEFIN_DELL_IPU7_KERNEL_EVR=7.1.2-355.vanilla.fc44 \
  --build-arg PURPLEFIN_OSTREE_LINUX=7.1.2-355.vanilla.fc44.x86_64 \
  --label ostree.linux=7.1.2-355.vanilla.fc44.x86_64 \
  --tag ghcr.io/declarative-dale/purplefin:dell-xps-9350-intel \
  .
```

The no-IPU7 Dell test profile uses the same pinned mainline kernel by default.
Its neutral canary arguments are
`PURPLEFIN_DELL_MAINLINE_KERNEL_EVR` and
`PURPLEFIN_DELL_MAINLINE_KERNEL_ALLOW_UNPINNED`.

## Switch To The Image

Generic profile:

```bash
sudo bootc switch ghcr.io/declarative-dale/purplefin:generic-x86_64
```

Dell XPS 9350 Intel profile:

```bash
sudo bootc switch ghcr.io/declarative-dale/purplefin:dell-xps-9350-intel
```

Dell XPS 9350 Intel no-IPU7 test profile:

```bash
sudo bootc switch ghcr.io/declarative-dale/purplefin:dell-xps-9350-intel-no-ipu7
```

Reboot after switching.

The `latest` tag tracks the generic profile. Use the `dell-xps-9350-intel`
tag for the full Dell IPU7 profile or `dell-xps-9350-intel-no-ipu7` for the
Dell no-camera test profile. The full Dell camera profile uses the pinned
7.1.2 fallback only while Bluefin's kernel is older than 7.1.2, then follows
Bluefin's kernel. Every profile bakes in Packer, Ansible, OpenTofu, and OpenBao;
their commands are `packer`, `ansible`, `tofu`, and `bao`, respectively. The
base image also bakes Bitwarden's official native `bw` CLI inside a
Purplefin-built RPM, Fedora's `wireguard-tools`, and a launchable NetworkManager
connection editor for the preferred native WireGuard UI. Every profile
preinstalls the Nextcloud desktop client and Cameractrls from Flathub. Gear
Lever remains preinstalled for installing, launching, updating, and organizing
user-provided AppImages, and Fedora's FUSE 2 runtime remains available for
direct AppImage execution. Inherited Tailscale packages, services,
repositories, setup hooks, and user-facing tips are removed from every profile.
Terra's Bitwarden packages are excluded so future DNF operations cannot
reintroduce the desktop RPM after migration to Flatpak.

Bitwarden desktop is installed system-wide from Bitwarden's verified Flathub
package. A Purplefin timer checks it for updates twice daily, independently of
the bootc image lifecycle, and the image includes Bitwarden's polkit policy for
Linux system-authentication unlock. The native `/usr/bin/bw` CLI remains a
Purplefin-built RPM in the bootc image: its official versioned archive and
GitHub-published SHA-256 digest are pinned in `build_files/bitwarden-cli.env`.
A daily GitHub workflow checks for a new CLI release and opens a pull request;
merging that update builds the version into the next Purplefin deployment.
Both Dell profiles bake in `1password-cli`; the 1Password desktop RPM is
layered by a first-boot rpm-ostree task and becomes available after the reboot
into that staged deployment.

To request immediate update checks instead of waiting for the timers and
scheduled workflow, use:

```bash
sudo systemctl start purplefin-bitwarden-flatpak-update.service
bw update
sudo bootc upgrade
```

`bw update` reports whether the image-baked CLI is behind upstream; it does not
replace the binary. A merged automated CLI update and a subsequent bootc image
upgrade perform that replacement atomically.

### Migrating Bitwarden from the layered RPM

Purplefin images built before this change layer Bitwarden's desktop RPM on the
host during first boot. The replacement image preinstalls the verified Flatpak
and carries a one-time migration task that removes the old RPM layer without
deleting its per-user data.

Before upgrading, make sure the vault has completed a sync. Then deploy and
boot the updated image:

```bash
sudo bootc upgrade
sudo systemctl reboot
```

On the first boot into the updated image,
`purplefin-firstboot-rpm-ostree.service` detects the legacy `bitwarden` layer
and stages its removal. If a removal was staged, reboot once more:

```bash
systemctl status purplefin-firstboot-rpm-ostree.service
sudo systemctl reboot
```

The Flatpak uses `~/.var/app/com.bitwarden.desktop/` rather than the native
client's `~/.config/Bitwarden/` state. Launch the Flatpak and sign in again;
keep the old directory until the new client has synced and all expected vault
items are present. The native CLI keeps its existing configuration and remains
available as `/usr/bin/bw`.

Verify the completed migration with:

```bash
! rpm -q bitwarden
flatpak info --system com.bitwarden.desktop
rpm -q purplefin-bitwarden-cli
bw --version
systemctl status purplefin-bitwarden-flatpak-update.timer
test -f /usr/share/polkit-1/actions/com.bitwarden.Bitwarden.policy
```

If the one-time task did not remove the old layer, remove it explicitly and
reboot before launching the Flatpak:

```bash
sudo rpm-ostree uninstall bitwarden
sudo systemctl reboot
flatpak install --system flathub com.bitwarden.desktop
```

After migration, enable **Unlock with system authentication** in Bitwarden if
desired. A rollback to a pre-migration bootc deployment may temporarily expose
both desktop packages because Flatpak state persists outside the bootc image;
use the Flatpak, then upgrade forward again.

### Migrating from the Nextcloud AppImage

Purplefin images built before this change contain a Nextcloud AppImage in the
immutable `/usr` deployment. Deploy the updated image and reboot to remove the
AppImage, its `/usr/bin/nextcloud` link, desktop file, icon, and provenance file.
The shared Flatpak preinstall service installs the replacement automatically.
If it has not run yet, install the replacement explicitly:

```bash
flatpak install --system flathub com.nextcloud.desktopclient.nextcloud
```

Before rebooting, quit the old client with `pkill -x nextcloud` if it is still
running. After rebooting, verify the migration with:

```bash
test ! -e /usr/libexec/purplefin/appimages/Nextcloud.AppImage
test ! -e /usr/share/purplefin/nextcloud-appimage.provenance
flatpak info com.nextcloud.desktopclient.nextcloud
```

Nextcloud's Flatpak keeps application state in its sandbox, so launch it and
configure the account again if the existing AppImage settings are not imported.

## Dell IPU7 Camera Flow

The Dell XPS 9350 Intel profile targets the Lunar Lake IPU7 (`8086:645d`),
Intel CVS (`INTC10DE`), and OV02C10 (`OVTI02C1`) camera in this laptop. The
generic and `dell-xps-9350-intel-no-ipu7` profiles do not install its module,
activation rules, or camera-specific userspace configuration.

IPU7 setup requires stable Linux 7.1.2 or newer; release candidates and older
kernels are rejected. At image-build time Purplefin reads Bluefin's inherited
`kernel-core` package. If its upstream version is older than 7.1.2, Purplefin
replaces it with the pinned EVR `7.1.2-355.vanilla.fc44`. As soon as Bluefin
ships 7.1.2 or newer, Purplefin keeps Bluefin's exact kernel instead. The same
decision is written to `/usr/share/purplefin/dell-ipu7/kernel-selection`, and
the build sets the OCI `ostree.linux` label to that exact release. Explicit
canary overrides remain available through `PURPLEFIN_DELL_IPU7_KERNEL_EVR` and
`PURPLEFIN_DELL_IPU7_KERNEL_ALLOW_UNPINNED`; exact EVRs can be blocked in
`/usr/share/purplefin/dell-ipu7/kernel-evr.denylist`.

Linux 7.1 has the in-tree IPU7 ISYS, USBIO, and OV02C10 drivers but not the
Lunar Lake CVS ownership fix. Purplefin therefore builds only `intel_cvs` from
Intel's `vision-drivers` commit
`845d6f8bdf66ff1f455901da9de5e00a53a83dce` (tag `26WW19.4_NVL`). That commit
guards the protocol-2-only host identifier command and works with the
protocol-1 CVS in this laptop. The module is compiled into the image against
the exact selected 7.1.x kernel; it is not built with DKMS after boot because the
Atomic host mounts `/usr/src` and `/usr/lib/modules` read-only.

The flow is:

1. The Dell profile keeps Bluefin's kernel when it is at least 7.1.2. Otherwise
   it temporarily enables the Dell-only mainline repo, installs the exact
   pinned 7.1.2 fallback, prunes the obsolete inherited module tree, and removes
   the temporary repo. Both paths validate the OV02C10, IPU7, and USBIO config.
2. The build accepts Fedora's compressed `ipu7_fw.bin.xz`/`.zst` firmware,
   temporarily installs exact matching `kernel-devel` when required, compiles the pinned Intel CVS
   module, verifies its kernel vermagic and `INTC10DE` alias, installs it under
   the target kernel's module tree, runs `depmod`, and removes build-only
   packages.
3. Fedora's stock `libcamera`, `libcamera-ipa`, `libcamera-tools`, and
   `pipewire-plugin-libcamera` provide the Simple pipeline and GPU SoftISP.
   No PSYS module, custom OV08X40 pipeline, `/usr/local` libcamera,
   v4l2loopback device, or proprietary camera HAL is installed.
4. At boot, `intel_cvs` performs the camera-ownership handshake. A udev rule
   and `purplefin-dell-ipu7-camera.service` then rebind `i2c-OVTI02C1:00` to
   `ov02c10`, covering the early-probe race documented in Fedora bug 2413472.
5. WirePlumber suppresses the 32 raw V4L2 devices whose description is `ipu7`.
   Those are ISYS capture endpoints, not webcams. The libcamera monitor remains
   enabled and publishes the single usable camera. A user service configures
   each Flathub Firefox profile to use its PipeWire camera backend, preventing
   Firefox from bypassing WirePlumber and enumerating the raw V4L2 nodes.
6. On Linux 7.2 or newer, the build instead requires
   `CONFIG_VIDEO_INTEL_CVS` and the in-tree `intel_cvs` module with the Dell
   `INTC10DE` alias, and does not build or install the external module.

This workaround is based on the same-hardware Fedora report at
`https://bugzilla.redhat.com/show_bug.cgi?id=2413472`. Native CVS/IPU bridge
support first appears in Linux 7.2, which is the automatic handoff point for
the in-tree CVS provider. The external 7.1.x module is unsigned, so Secure Boot
must remain disabled on that path unless a locally enrolled module-signing key
is added.

Runtime verification on the Dell laptop:

```bash
uname -r
cat /usr/share/purplefin/dell-ipu7/kernel-selection
modinfo -n intel_cvs
readlink -f /sys/bus/i2c/devices/i2c-INTC10DE:00/driver
readlink -f /sys/bus/i2c/devices/i2c-OVTI02C1:00/driver
journalctl -k -b | grep -Ei 'ipu7|intel.cvs|ov02c10|firmware'
cam -l
rg 'media.webrtc.camera.allow-pipewire' \
  ~/.var/app/org.mozilla.firefox/config/mozilla/firefox/*/user.js
```

`cam -l` should report one OV02C10 camera. After restarting WirePlumber, its
graph should contain no raw V4L2 devices described as `ipu7` and one libcamera
camera source. After Firefox has created a profile, log out and back in (or run
`systemctl --user start purplefin-firefox-pipewire-camera.service`) and restart
Firefox. Firefox should then show one internal camera instead of dozens of
non-working IPU7 inputs.

## What Is Tracked

- Base image selection and build profile logic.
- A centralized first-boot rpm-ostree runner with ordered task scripts and `/var/lib/purplefin/firstboot/*.done` markers. It stops after a task stages a deployment so later rpm-ostree tasks run after the next reboot instead of replacing earlier queued changes.
- System Flatpak preinstall manifest generated from this laptop, including the
  verified Bitwarden desktop package and its twice-daily update timer.
- Homebrew `Brewfile` generated from this laptop.
- Image-baked Packer, Ansible, OpenTofu, and OpenBao tooling for every profile.
- Bitwarden's official native CLI payload under `/usr/bin/bw`, wrapped without
  modification in a Purplefin-built RPM from a pinned versioned archive and
  SHA-256 digest, plus a daily workflow that proposes CLI release updates.
- A one-time first-boot migration that removes the legacy Bitwarden desktop RPM
  layer after the verified Flatpak replacement is deployed.
- Fedora `wireguard-tools` and the launchable NetworkManager connection editor
  as the native WireGuard CLI and GUI for every profile.
- Nextcloud Desktop Client and Cameractrls as base Flatpaks inherited by every
  profile, plus Gear Lever and Fedora's FUSE 2 runtime for user-managed
  AppImages and application-menu integration.
- Removal of inherited Tailscale packages, enabled services, and RPM repository
  configuration from every profile.
- A first-boot, idempotent Homebrew bundle service.
- Vates planet boot, Plymouth, GDM login, and legacy Bluefin logo-path branding over the inherited Bluefin/Fedora assets.
- Dell XPS 9350 Intel 1Password RPM repo plus baked `1password-cli`.
- Dell XPS 9350 Intel first-boot rpm-ostree task that layers the 1Password desktop RPM on installed systems. The desktop RPM writes under `/opt`, which is supported by rpm-ostree layering on the target host but fails during direct bootc container package installation.
- Dell XPS 9350 Intel conditional 7.1.2 fallback until Bluefin reaches that version, exact kernel OCI metadata, external CVS for 7.1.x, validated in-tree CVS for 7.2+, OV02C10 reprobe compatibility, stock Fedora libcamera integration, and WirePlumber filtering for raw IPU7 endpoints.
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
