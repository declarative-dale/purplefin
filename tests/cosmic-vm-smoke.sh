#!/usr/bin/env bash
set -euo pipefail

image_ref="${1:?usage: cosmic-vm-smoke.sh IMAGE_REF}"
if ((EUID != 0)); then
	echo 'cosmic-vm-smoke.sh must run as root for bootc-image-builder' >&2
	exit 1
fi

smoke_user=cosmic-smoke
smoke_password="$(od -An -N16 -tx1 /dev/urandom | tr -d ' \n')"
ssh_port="${COSMIC_SMOKE_SSH_PORT:-2222}"
smoke_root="$(mktemp -d)"
output_dir="${smoke_root}/output"
ssh_key="${smoke_root}/id_ed25519"
qemu_pid=''

cleanup() {
	if [[ -n "${qemu_pid}" ]] && kill -0 "${qemu_pid}" 2>/dev/null; then
		kill "${qemu_pid}" 2>/dev/null || true
		wait "${qemu_pid}" 2>/dev/null || true
	fi
	rm -rf "${smoke_root}"
}
trap cleanup EXIT

for command in podman qemu-system-x86_64 ssh ssh-keygen; do
	command -v "${command}" >/dev/null 2>&1 || {
		echo "${command} is required for the COSMIC VM smoke test" >&2
		exit 1
	}
done

mkdir -p "${output_dir}"
ssh-keygen -q -t ed25519 -N '' -f "${ssh_key}"
public_key="$(<"${ssh_key}.pub")"

cat >"${smoke_root}/config.toml" <<EOF
[customizations.services]
enabled = ["sshd"]

[[customizations.user]]
name = "${smoke_user}"
password = "${smoke_password}"
key = "${public_key}"
groups = ["wheel"]
EOF

for ((pull_attempt = 1; pull_attempt <= 5; pull_attempt += 1)); do
	if podman pull "${image_ref}"; then
		break
	fi
	if ((pull_attempt == 5)); then
		echo "Failed to pull ${image_ref} after ${pull_attempt} attempts" >&2
		exit 1
	fi
	echo "Retrying ${image_ref} pull (${pull_attempt}/5)" >&2
	sleep 5
done
podman run \
	--rm \
	--privileged \
	--pull=newer \
	--security-opt label=type:unconfined_t \
	--volume "${smoke_root}/config.toml:/config.toml:ro" \
	--volume "${output_dir}:/output" \
	--volume /var/lib/containers/storage:/var/lib/containers/storage \
	quay.io/centos-bootc/bootc-image-builder:latest \
	--type qcow2 \
	--rootfs ext4 \
	--use-librepo=True \
	"${image_ref}"

disk_image="${output_dir}/qcow2/disk.qcow2"
test -f "${disk_image}"

firmware=''
for candidate in /usr/share/OVMF/OVMF_CODE_4M.fd /usr/share/OVMF/OVMF_CODE.fd; do
	if [[ -f "${candidate}" ]]; then
		firmware="${candidate}"
		break
	fi
done
[[ -n "${firmware}" ]] || { echo 'OVMF firmware was not found' >&2; exit 1; }

accel_args=(-accel tcg,thread=multi -cpu max)
if [[ -r /dev/kvm && -w /dev/kvm ]]; then
	accel_args=(-enable-kvm -cpu host)
fi

qemu-system-x86_64 \
	"${accel_args[@]}" \
	-machine q35 \
	-smp 4 \
	-m 6144 \
	-bios "${firmware}" \
	-drive "file=${disk_image},if=virtio,format=qcow2" \
	-device virtio-vga \
	-netdev "user,id=net0,hostfwd=tcp:127.0.0.1:${ssh_port}-:22" \
	-device virtio-net-pci,netdev=net0 \
	-display none \
	-monitor none \
	-serial "file:${smoke_root}/serial.log" &
qemu_pid=$!

ssh_args=(
	-i "${ssh_key}"
	-p "${ssh_port}"
	-o BatchMode=yes
	-o ConnectTimeout=5
	-o StrictHostKeyChecking=no
	-o UserKnownHostsFile=/dev/null
)

wait_for_ssh() {
	local attempts="${1:-120}"
	local attempt
	for ((attempt = 1; attempt <= attempts; attempt += 1)); do
		if ssh "${ssh_args[@]}" "${smoke_user}@127.0.0.1" true 2>/dev/null; then
			return 0
		fi
		if ! kill -0 "${qemu_pid}" 2>/dev/null; then
			tail -n 200 "${smoke_root}/serial.log" >&2 || true
			echo 'COSMIC smoke-test VM exited before SSH became available' >&2
			return 1
		fi
		sleep 5
	done
	tail -n 200 "${smoke_root}/serial.log" >&2 || true
	echo 'Timed out waiting for the COSMIC smoke-test VM' >&2
	return 1
}

wait_for_ssh

ssh "${ssh_args[@]}" "${smoke_user}@127.0.0.1" \
	"printf '%s\\n' '${smoke_password}' | sudo -S sed -i '/^\\[daemon\\]$/a AutomaticLoginEnable=True\\nAutomaticLogin=${smoke_user}' /etc/gdm/custom.conf"
ssh "${ssh_args[@]}" "${smoke_user}@127.0.0.1" \
	"printf '%s\\n' '${smoke_password}' | sudo -S systemctl reboot" || true

for ((attempt = 1; attempt <= 60; attempt += 1)); do
	if ! ssh "${ssh_args[@]}" "${smoke_user}@127.0.0.1" true 2>/dev/null; then
		break
	fi
	sleep 2
done
wait_for_ssh

session_smoke="$(dirname "${BASH_SOURCE[0]}")/cosmic-session-smoke.sh"
for ((attempt = 1; attempt <= 60; attempt += 1)); do
	if ssh "${ssh_args[@]}" "${smoke_user}@127.0.0.1" \
		"COSMIC_SMOKE_USER='${smoke_user}' bash -s" <"${session_smoke}"; then
		exit 0
	fi
	sleep 5
done

ssh "${ssh_args[@]}" "${smoke_user}@127.0.0.1" \
	"printf '%s\\n' '${smoke_password}' | sudo -S journalctl -b --no-pager -u gdm -n 200" >&2 || true
echo 'Timed out waiting for the automatic COSMIC login session' >&2
exit 1
