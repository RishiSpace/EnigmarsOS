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

echo "==> EnigmarsOS: seed-kernel into ${ROOT}/boot"
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
  shopt -s nullglob
  for src in "${src_dir}"/vmlinuz-* "${src_dir}"/initramfs-*.img "${src_dir}"/amd-ucode.img "${src_dir}"/intel-ucode.img; do
    [[ -f "${src}" ]] || continue
    if copy_one "${src}" "${ROOT}/boot/$(basename "${src}")"; then
      [[ "$(basename "${src}")" == vmlinuz-* ]] && copied_kernel=1
    fi
  done
  shopt -u nullglob
done

if [[ ${copied_kernel} -eq 0 ]]; then
  found="$(find /run/archiso /boot -type f \( -name 'vmlinuz-linux-enigmarsos' -o -name 'vmlinuz-linux' \) 2>/dev/null | head -1 || true)"
  if [[ -n "${found}" ]]; then
    copy_one "${found}" "${ROOT}/boot/$(basename "${found}")" && copied_kernel=1
    bdir="$(dirname "${found}")"
    shopt -s nullglob
    for src in "${bdir}"/initramfs-*.img "${bdir}"/amd-ucode.img "${bdir}"/intel-ucode.img; do
      [[ -f "${src}" ]] || continue
      copy_one "${src}" "${ROOT}/boot/$(basename "${src}")" || true
    done
    shopt -u nullglob
  fi
fi

if [[ ! -r "${ROOT}/boot/vmlinuz-linux-enigmarsos" && ! -r "${ROOT}/boot/vmlinuz-linux" ]]; then
  echo "ERROR: could not seed a kernel into target /boot" >&2
  echo "Live /boot:" >&2
  ls -la /boot 2>&1 || true
  echo "ISO mounts:" >&2
  ls -la /run/archiso/bootmnt 2>&1 || true
  find /run/archiso /boot -name 'vmlinuz*' 2>/dev/null | head || true
  exit 1
fi

echo "==> Target kernels:"
ls -l "${ROOT}/boot"/vmlinuz-* 2>/dev/null || true
echo "==> EnigmarsOS: seed-kernel done"
