#!/usr/bin/env bash
# Seed /boot on the Calamares TARGET from the live ISO session (offline-safe).
# Invoked with dontChroot: true.
# ROOT comes from: env ROOT=… and/or argv $1 (Calamares expands ${ROOT}).
set -euo pipefail

if [[ -n "${1:-}" ]]; then
  ROOT="$1"
fi
ROOT="${ROOT:-}"

if [[ -z "${ROOT}" || ! -d "${ROOT}" ]]; then
  echo "ERROR: ROOT is not set or not a directory (got: '${ROOT:-}')" >&2
  echo "Usage: $0 /path/to/target   OR   env ROOT=/path/to/target $0" >&2
  echo "Debug mounts:" >&2
  ls -ld /tmp/calamares-root-* 2>/dev/null || true
  findmnt | head -40 || true
  exit 1
fi

echo "==> EnigmaOS: seed-kernel into ${ROOT}/boot"
mkdir -p "${ROOT}/boot"

copy_one() {
  local src="$1"
  local dest="$2"
  if [[ -r "${src}" ]]; then
    cp -a "${src}" "${dest}"
    echo "    copied $(basename "${src}") <- ${src}"
    return 0
  fi
  return 1
}

copied_kernel=0

# Live /boot and common archiso ISO paths
for src_dir in \
  /boot \
  /run/archiso/bootmnt/arch/boot/x86_64 \
  /run/archiso/bootmnt/boot/x86_64 \
  /run/archiso/bootmnt/boot
do
  [[ -d "${src_dir}" ]] || continue
  if copy_one "${src_dir}/vmlinuz-linux" "${ROOT}/boot/vmlinuz-linux"; then
    copied_kernel=1
  fi
  copy_one "${src_dir}/initramfs-linux.img" "${ROOT}/boot/initramfs-linux.img" || true
  copy_one "${src_dir}/initramfs-linux-fallback.img" "${ROOT}/boot/initramfs-linux-fallback.img" || true
  copy_one "${src_dir}/amd-ucode.img" "${ROOT}/boot/amd-ucode.img" || true
  copy_one "${src_dir}/intel-ucode.img" "${ROOT}/boot/intel-ucode.img" || true
done

if [[ ${copied_kernel} -eq 0 ]]; then
  found="$(find /run/archiso /boot -type f -name 'vmlinuz-linux' 2>/dev/null | head -1 || true)"
  if [[ -n "${found}" ]]; then
    copy_one "${found}" "${ROOT}/boot/vmlinuz-linux" && copied_kernel=1
    bdir="$(dirname "${found}")"
    copy_one "${bdir}/initramfs-linux.img" "${ROOT}/boot/initramfs-linux.img" || true
    copy_one "${bdir}/initramfs-linux-fallback.img" "${ROOT}/boot/initramfs-linux-fallback.img" || true
    copy_one "${bdir}/amd-ucode.img" "${ROOT}/boot/amd-ucode.img" || true
    copy_one "${bdir}/intel-ucode.img" "${ROOT}/boot/intel-ucode.img" || true
  fi
fi

if [[ ! -r "${ROOT}/boot/vmlinuz-linux" ]]; then
  echo "ERROR: could not seed vmlinuz-linux into target /boot" >&2
  echo "Live /boot:" >&2
  ls -la /boot 2>&1 || true
  echo "ISO mounts:" >&2
  ls -la /run/archiso/bootmnt 2>&1 || true
  find /run/archiso /boot -name 'vmlinuz*' 2>/dev/null | head || true
  exit 1
fi

echo "==> Target kernel: $(ls -l "${ROOT}/boot/vmlinuz-linux")"
echo "==> EnigmaOS: seed-kernel done"
