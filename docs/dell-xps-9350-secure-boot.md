# Dell XPS 13 9350 Secure Boot migration

Last verified: 2026-07-13

This runbook migrates the `dell-xps-9350-intel` Purplefin profile to UEFI
Secure Boot after its camera stack has handed `intel_cvs` over to the signed,
in-tree Linux driver. It does not cover signing Purplefin's external CVS
fallback locally.

> [!CAUTION]
> Do not enable Secure Boot while `modinfo -n intel_cvs` resolves below
> `updates/purplefin`, while `modinfo -F signer intel_cvs` is empty, or while
> `/usr/share/purplefin/dell-ipu7/kernel-selection` says anything other than
> `cvs_provider=in-tree`. The current Linux 7.1.x fallback deliberately installs
> an unsigned external module and is not a Secure Boot migration target.

## Why Linux 7.2 is the handoff

The profile has two mutually exclusive CVS providers:

- Stable Linux 7.1.x builds compile Intel's pinned external `intel_cvs` and
  install it at
  `/usr/lib/modules/$release/updates/purplefin/intel_cvs.ko`. That module is
  unsigned.
- Final Linux 7.2 or newer builds require `CONFIG_VIDEO_INTEL_CVS`, require
  `intel_cvs` to resolve from `kernel/drivers/media/i2c/cvs`, verify the Dell
  `INTC10DE` alias, and do not install the external module.

The build fails rather than silently crossing that boundary with the wrong
provider. See the [profile implementation](../build_files/profiles/dell-xps-9350-intel.sh)
and [shared kernel-selection helpers](../profile_files/dell-xps-9350-intel/system_files/usr/libexec/purplefin/lib/dell-ipu7.sh).
The upstream driver was tested on an XPS 13 9350 and merged for Linux 7.2 in
[Linux commit 8e2b43d2c10b](https://github.com/torvalds/linux/commit/8e2b43d2c10b1b5f42805810c6854470d8774e60).

## Prerequisites

Complete all of these before changing firmware settings:

1. Use AC power and arrange physical access to the laptop.
2. Have a Fedora/Bluefin recovery USB and the full LUKS passphrase, not only
   TPM automatic unlock. A Secure Boot policy change can change TPM PCR 7.
3. Boot and test the candidate Purplefin deployment once with Secure Boot still
   disabled. It must use a final kernel at least 7.2.0; release candidates do
   not pass the profile's supported-kernel gate.
4. Keep a bootable 7.1.2 deployment as the rollback. It can be used only after
   Secure Boot is disabled again because it contains the unsigned external CVS
   module.
5. Use the Fedora shim boot entry. On the audited laptop `efibootmgr -v` showed
   `BootCurrent: 0003` and `Boot0003 Fedora ... \\EFI\\fedora\\shimx64.efi`.
   An old rEFInd entry also exists, but it is outside this migration and must
   not replace the Fedora entry unless its entire chain is separately verified.

If TPM-bound unlock is in use, verify the recovery passphrase before proceeding.
Do not clear the TPM and do not erase Dell's factory Secure Boot keys.

## Gate the candidate deployment

Run this in a host terminal, not a container. Every check must succeed:

```bash
set -euo pipefail

selection=/usr/share/purplefin/dell-ipu7/kernel-selection
test -r "$selection"
# This file is immutable image metadata produced by the Purplefin build.
source "$selection"

test "$target_release" = "$(uname -r)"
test "$cvs_provider" = in-tree
case "${target_version,,}" in
  *rc*)
    printf 'STOP: release-candidate kernel: %s\n' "$target_version" >&2
    exit 1
    ;;
esac
test "$(printf '%s\n' 7.2.0 "$target_version" | sort -V | tail -n 1)" = "$target_version"

module_path=$(modinfo -n intel_cvs)
case "$module_path" in
  /lib/modules/"$(uname -r)"/kernel/drivers/media/i2c/cvs/intel_cvs.ko|\
  /lib/modules/"$(uname -r)"/kernel/drivers/media/i2c/cvs/intel_cvs.ko.xz|\
  /lib/modules/"$(uname -r)"/kernel/drivers/media/i2c/cvs/intel_cvs.ko.zst|\
  /usr/lib/modules/"$(uname -r)"/kernel/drivers/media/i2c/cvs/intel_cvs.ko|\
  /usr/lib/modules/"$(uname -r)"/kernel/drivers/media/i2c/cvs/intel_cvs.ko.xz|\
  /usr/lib/modules/"$(uname -r)"/kernel/drivers/media/i2c/cvs/intel_cvs.ko.zst)
    ;;
  *)
    printf 'STOP: unexpected intel_cvs path: %s\n' "$module_path" >&2
    exit 1
    ;;
esac

test ! -e "/usr/lib/modules/$(uname -r)/updates/purplefin/intel_cvs.ko"
test ! -e "/lib/modules/$(uname -r)/updates/purplefin/intel_cvs.ko"

cvs_signer=$(modinfo -F signer intel_cvs)
ipu7_signer=$(modinfo -F signer intel_ipu7)
test -n "$cvs_signer"
test "$cvs_signer" = "$ipu7_signer"
test "$(modinfo -F sig_id intel_cvs)" = PKCS#7
modinfo -F alias intel_cvs | rg -Fx 'acpi*:INTC10DE:*'
modinfo -F vermagic intel_cvs | rg -q "^$(uname -r) "

printf 'PASS: %s\nPASS: signer=%s\n' "$module_path" "$cvs_signer"
```

The important result is not merely a `7.2` version string. The module must be
the kernel-tree file, have a nonempty signature, and use the same signer as the
matching in-tree IPU7 module. Stop if any assertion fails.

Also establish a functional baseline while Secure Boot is disabled:

```bash
readlink -f /sys/bus/i2c/devices/i2c-INTC10DE:00/driver
readlink -f /sys/bus/i2c/devices/i2c-OVTI02C1:00/driver
cam -l
fprintd-verify "$USER"
journalctl -k -b --no-pager | rg -i 'ipu7|intel.cvs|ov02c10|firmware'
```

The two drivers should resolve to Intel CVS and `ov02c10`, and `cam -l` should
show one OV02C10 camera. Fix baseline failures before continuing.

## Back up the boot state and retain rollback deployments

Create a private audit bundle and copy the EFI System Partition while it is
known to boot:

```bash
backup="$HOME/secure-boot-migration-$(date +%Y%m%d-%H%M%S)"
install -d -m 0700 "$backup"

uname -a >"$backup/uname.txt"
rpm-ostree status >"$backup/rpm-ostree-status.txt"
ostree admin status >"$backup/ostree-admin-status.txt"
efibootmgr -v >"$backup/efibootmgr.txt"
mokutil --sb-state >"$backup/secure-boot-state.txt"
mokutil --list-enrolled >"$backup/mok-enrolled.txt"
cp /usr/share/purplefin/dell-ipu7/kernel-selection "$backup/"
run0 --pipe tar -C /boot/efi -cpf - . | gzip >"$backup/efi.tar.gz"
tar -tzf "$backup/efi.tar.gz" >/dev/null
```

Pin the tested candidate and the previous deployment so automatic cleanup does
not remove either one:

```bash
run0 ostree admin pin booted
run0 ostree admin pin rollback
ostree admin status
```

`rollback` must exist before the second command is run. OSTree deployments
share `/var`, so rollback protects the operating-system tree; it is not a
backup of home data.

## Verify or enroll Bluefin's key

Bluefin installs its current certificate here:

```bash
test -r /etc/pki/akmods/certs/akmods-ublue.der
openssl x509 -inform DER \
  -in /etc/pki/akmods/certs/akmods-ublue.der \
  -noout -subject -fingerprint -sha256
mokutil --list-enrolled --short | rg -F 'ublue kernel'
```

At the audit date the certificate was:

```text
subject=O=Universal Blue, OU=kernel signing, CN=ublue kernel, emailAddress=security@universal-blue.org
sha256 Fingerprint=4E:5C:68:47:4C:B1:33:FD:89:84:D9:59:97:62:CE:CE:91:00:C3:E6:CD:8A:97:09:AE:AA:BD:85:DD:9E:70:D1
```

Compare the installed certificate, rather than permanently trusting this
dated fingerprint; Universal Blue can rotate keys. Bluefin's official
user-facing command is `ujust enroll-secure-boot-key`. The equivalent explicit
commands using Bluefin's polkit-backed privilege path are:

```bash
run0 mokutil --timeout -1
run0 mokutil --import /etc/pki/akmods/certs/akmods-ublue.der
mokutil --list-new
```

When `mokutil` asks for the one-time MOK password, enter `universalblue` twice,
matching Bluefin's published procedure. Do not import another downloaded key
over the installed certificate. If `ublue kernel` is already enrolled and
there is no pending import, do not enqueue it again.

With Secure Boot disabled, `mokutil --test-key` can print “already enrolled”
but still return nonzero because the trusted kernel keyring is unavailable.
Use `--list-enrolled` at this stage and repeat `--test-key` after Secure Boot is
enabled.

## Dell BIOS and MOK enrollment sequence

1. Save work, then enter firmware setup with:

   ```bash
   run0 systemctl reboot --firmware-setup
   ```

   If firmware setup is not entered automatically, restart and tap **F2** at
   the Dell logo. **F12** opens Dell's one-time boot menu.

2. In **Boot Configuration**, keep **Boot Mode: UEFI only** and ensure legacy
   option ROMs are disabled.
3. Enable Advanced Setup if necessary. Under **Secure Boot**:
   - enable **Enable Secure Boot**;
   - leave **Secure Boot Mode** at **Deployed Mode**;
   - leave **Enable Custom Mode** disabled;
   - do not delete PK, KEK, `db`, or `dbx` keys.
4. Apply the setting and exit. Boot the **Fedora** shim entry.
5. If `mokutil --list-new` showed a pending request, the blue MokManager screen
   should appear. Its keyboard layout is US QWERTY. Choose **Enroll MOK**,
   review/continue, confirm **Yes**, enter `universalblue`, and reboot. Exact
   intermediate wording varies slightly by shim version. If the current
   `ublue kernel` key was already enrolled, no MokManager screen is expected;
   Purplefin should boot directly.

If a request was pending but MokManager does not appear, do not reset firmware
keys. Disable Secure Boot, boot Purplefin again, inspect `mokutil --list-new`,
and enqueue the installed Bluefin certificate again if necessary.

## Verify the secured boot

First verify the boot chain, enrolled key, and CVS provider:

```bash
mokutil --sb-state
mokutil --test-key /etc/pki/akmods/certs/akmods-ublue.der
mokutil --list-enrolled --short | rg -F 'ublue kernel'
efibootmgr -v | rg 'BootCurrent|Fedora|shimx64'

modinfo -n intel_cvs
modinfo -F signer intel_cvs
modinfo -F signer intel_ipu7
test -z "$(tr -d '\n' </sys/module/intel_cvs/taint)"

journalctl -k -b --no-pager | \
  rg -i 'secure boot|lockdown|intel.cvs|ipu7|ov02c10|module verification|out-of-tree'
```

Required results:

- `mokutil --sb-state` says `SecureBoot enabled`.
- `mokutil --test-key` succeeds for the installed `ublue kernel` certificate.
- `intel_cvs` still resolves from `kernel/drivers/media/i2c/cvs`, its signer is
  nonempty and matches `intel_ipu7`, and its module taint content is empty.
- The journal has no `intel_cvs: loading out-of-tree module` and no
  `intel_cvs: module verification failed` message.

Then test hardware from the graphical user session:

```bash
systemctl status purplefin-dell-ipu7-camera.service --no-pager
systemctl --user status pipewire.service wireplumber.service --no-pager

readlink -f /sys/bus/i2c/devices/i2c-INTC10DE:00/driver
readlink -f /sys/bus/i2c/devices/i2c-OVTI02C1:00/driver
cam -l

pw-dump | jq -r '
  .[]
  | select(.type == "PipeWire:Interface:Node")
  | .info.props
  | select(.["media.class"] == "Video/Source")
  | [.["node.name"], .["node.description"]]
  | @tsv
'

fprintd-verify "$USER"
```

Expect one usable libcamera/OV02C10 camera source and no raw video sources whose
description is merely `ipu7`. Confirm live video in Firefox as well as listing
the camera. Fingerprint verification should complete normally.

Finally, save work and perform two suspend/resume cycles:

```bash
run0 systemctl suspend
```

After each resume, repeat `cam -l`, make a short live-video test, verify the
fingerprint reader, and inspect the current boot:

```bash
journalctl -k -b --since '-10 minutes' --no-pager | \
  rg -i 'ipu7|intel.cvs|ov02c10|runtime PM|suspend|resume|verification'
```

Treat a missing camera, a signature rejection, or a repeated IPU7 runtime-PM
failure accompanied by broken camera behavior as an incomplete migration.

## Failure recovery

### The system does not boot after Secure Boot is enabled

1. Press **F2** at the Dell logo.
2. Disable **Enable Secure Boot** only. Do not clear the TPM or erase Secure
   Boot databases.
3. Use **F12** and choose the Fedora shim entry.
4. Boot the pinned known-good deployment from the bootloader menu.

The 7.1.2 fallback is expected to load only after Secure Boot is disabled.

### The new deployment boots, but the camera or signed module fails

Collect evidence before rolling back:

```bash
uname -r
cat /usr/share/purplefin/dell-ipu7/kernel-selection
modinfo -n intel_cvs
modinfo -F signer intel_cvs
journalctl -k -b --no-pager | \
  rg -i 'secure boot|lockdown|ipu7|intel.cvs|ov02c10|verification|runtime PM'
```

Disable Secure Boot in Dell BIOS, boot the rollback deployment, and make it the
default if needed:

```bash
run0 rpm-ostree rollback
run0 systemctl reboot
```

Do not work around the failure by copying the external 7.1.x module into the
7.2 module tree or by disabling kernel signature validation.

### Cancel an enrollment that has not been completed

While Secure Boot is disabled and before completing MokManager enrollment:

```bash
mokutil --list-new
run0 mokutil --revoke-import
```

Deleting an already enrolled key is a separate, physical-console MOK operation
and is not required for normal rollback; leaving the Bluefin key enrolled while
temporarily disabling Secure Boot is safe.

## Linux 7.1.3 fallback status

Do **not** encode or recommend 7.1.3 as a Purplefin fallback as of the audit
date:

- Kernel.org identifies 7.1.3 as a final stable release, but its
  [changelog](https://cdn.kernel.org/pub/linux/kernel/v7.x/ChangeLog-7.1.3)
  contains no `ipu7`, `intel_cvs`, SoundWire, `xe:`, or Dell-specific entry.
  That is not hardware validation for this laptop.
- The Fedora 44 x86_64 metadata for Purplefin's configured
  [kernel-vanilla stable repository](https://download.copr.fedorainfracloud.org/results/@kernel-vanilla/stable/fedora-44-x86_64/repodata/repomd.xml)
  contained one coherent runtime/devel set:
  `7.1.2-355.vanilla.fc44`. Its primary metadata contained no 7.1.3 package.
- A 2026-07-19 inspection of `ghcr.io/projectbluefin/bluefin:stable` reported
  `ostree.linux=7.1.3-201.fc44.x86_64`. Purplefin therefore keeps that inherited
  kernel under its 7.1.2-or-newer handoff policy instead of using the pinned
  7.1.2 fallback.
- The inherited 7.1.3 kernel still uses the profile's external, unsigned CVS
  module path and therefore cannot satisfy this Secure Boot runbook.

The currently available recovery target remains the tested, pinned 7.1.2
deployment with Secure Boot disabled. Reassess repository availability and
hardware behavior before changing any kernel version pin.

## Authoritative references

- [Bluefin installation: Secure Boot](https://docs.projectbluefin.io/installation/#secure-boot)
- [Universal Blue akmods certificate repository](https://github.com/ublue-os/akmods/tree/main/certs)
- [Dell XPS 13 9350 system setup options](https://www.dell.com/support/manuals/en-us/xps-13-9350-intel-laptop/xps-13-9350-owners-manual/system-setup-options?guid=guid-b6a5d5e2-b180-4365-a992-8d5ae00b02be&lang=en-us)
- [Dell Secure Boot procedure](https://www.dell.com/support/kbdoc/en-us/000190116/how-to-enable-secure-boot-on-your-dell-device)
- [Fedora MOK and signed-module procedure](https://docs.fedoraproject.org/en-US/fedora/latest/system-administrators-guide/kernel-module-driver-configuration/Working_with_Kernel_Modules/)
- [Linux kernel module-signing documentation](https://docs.kernel.org/admin-guide/module-signing.html)
- [OSTree deployment pinning](https://ostreedev.github.io/ostree/man/ostree-admin-pin.html)
- [rpm-ostree rollback administration](https://coreos.github.io/rpm-ostree/administrator-handbook/)
- [systemd TPM PCR and Secure Boot policy documentation](https://www.freedesktop.org/software/systemd/man/latest/systemd-pcrlock.html)
- [Linux kernel release status](https://www.kernel.org/)
