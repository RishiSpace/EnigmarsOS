#!/usr/bin/env bash
# Seed /boot on the Calamares TARGET from the live ISO session (offline-safe).
# Invoked with dontChroot: true — ${ROOT} is the target root mount.
set -euo pipefail

ROOT="${ROOT:-}"
if [[ -z "${ROOT}" || ! -d "${ROOT}" ]]; then
  echo "ERROR: ROOT is not set or not a directory (got: '${ROOT:-}')" >&2
  exit 1
fi

echo "==> EnigmaOS: seed-kernel into ${ROOT}/boot"
mkdir -p "${ROOT}/boot"

copy_one() {
  local src="$1"
  local dest="$2"
  if [[ -r "${src}" ]]; then
    cp -a "${src}" "${dest}"
    echo "    copied $(basename "${src}")"
    return 0
  fi
  return 1
}

# Candidates: live /boot first, then archiso ISO mount layout
ISO_BOOT=""
for d in /run/archiso/bootmnt/arch/boot/x86_64 /run/archiso/bootmnt/boot /boot; do
  if [[ -d "${d}" ]]; then
    ISO_BOOT="${d}"
    break
  fi
done

copied_kernel=0
for src_dir in /boot ${ISO_BOOT}; do
  [[ -n "${src_dir}" && -d "${src_dir}" ]] || continue
  if copy_one "${src_dir}/vmlinuz-linux" "${ROOT}/boot/vmlinuz-linux"; then
    copied_kernel=1
  fi
  copy_one "${src_dir}/initramfs-linux.img" "${ROOT}/boot/initramfs-linux.img" || true
  copy_one "${src_dir}/initramfs-linux-fallback.img" "${ROOT}/boot/initramfs-linux-fallback.img" || true
  copy_one "${src_dir}/amd-ucode.img" "${ROOT}/boot/amd-ucode.img" || true
  copy_one "${src_dir}/intel-ucode.img" "${ROOT}/boot/intel-ucode.img" || true
done

# Some ISOs nest under arch/boot/<arch>/
if [[ ${copied_kernel} -eq 0 ]]; then
  found="$(find /run/archiso/bootmnt -type f -name 'vmlinuz-linux' 2>/dev/null | head -1 || true)"
  if [[ -n "${found}" ]]; then
    copy_one "${found}" "${ROOT}/boot/vmlinuz-linux" && copied_kernel=1
    bdir="$(dirname "${found}")"
    copy_one "${bdir}/initramfs-linux.img" "${ROOT}/boot/initramfs-linux.img" || true
    copy_one "${bdir}/initramfs-linux-fallback.img" "${ROOT}/boot/initramfs-linux-fallback.img" || true
  fi
fi

if [[ ! -r "${ROOT}/boot/vmlinuz-linux" ]]; then
  echo "ERROR: could not seed vmlinuz-linux into target /boot" >&2
  echo "Live /boot:" >&2
  ls -la /boot 2>&1 || true
  echo "ISO mounts:" >&2
  ls -la /run/archiso/bootmnt 2>&1 || true
  find /run/archiso -name 'vmlinuz*' 2>/dev/null | head || true
  exit 1
fi

# Ensure target thinks linux is present for pacman/bootloader tooling when possible.
# (Database may already list linux from the squashfs even if /boot files were stripped.)
echo "==> Target kernel: $(ls -l "${ROOT}/boot/vmlinuz-linux")"
echo "==> EnigmaOS: seed-kernel done"
