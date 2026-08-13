#!/usr/bin/env bash
# Repair an already-installed EnigmarsOS system whose Limine menu fails with:
#   "Failed to open kernel with path" / wrong uuid:UUID:/@/boot/... paths
#
# Root cause: Limine can only *read* FAT (and ISO9660). Kernels on btrfs must
# be copied to the ESP, and paths must use boot():/... or uuid(UUID):/...
#
# Run from the EnigmarsOS (or Arch) live USB as root. No ISO rebuild required.
#
# Usage:
#   sudo bash repair-limine-boot.sh
#   sudo bash repair-limine-boot.sh /dev/nvme0n1p2 /dev/nvme0n1p1
#     (root_partition  esp_partition)
set -uo pipefail

die() { echo "ERROR: $*" >&2; exit 1; }

if [[ "$(id -u)" -ne 0 ]]; then
  die "run as root (from live USB)"
fi

ROOT_PART="${1:-}"
ESP_PART="${2:-}"

echo "==> EnigmarsOS: repair Limine boot (stage kernels onto ESP)"

if [[ -z "${ROOT_PART}" || -z "${ESP_PART}" ]]; then
  echo "    Detecting partitions (lsblk)..."
  lsblk -o NAME,SIZE,FSTYPE,UUID,PARTLABEL,MOUNTPOINTS
  echo
  echo "    Tip: root is usually the large btrfs/ext4 partition;"
  echo "         ESP is the small vfat (~512M) partition."
  if [[ -z "${ROOT_PART}" ]]; then
    read -r -p "Root partition device (e.g. /dev/nvme0n1p2): " ROOT_PART
  fi
  if [[ -z "${ESP_PART}" ]]; then
    read -r -p "ESP partition device (e.g. /dev/nvme0n1p1): " ESP_PART
  fi
fi

[[ -b "${ROOT_PART}" ]] || die "not a block device: ${ROOT_PART}"
[[ -b "${ESP_PART}" ]] || die "not a block device: ${ESP_PART}"

MNT="$(mktemp -d /tmp/enigma-repair.XXXXXX)"
cleanup() {
  umount -R "${MNT}" 2>/dev/null || true
  rmdir "${MNT}" 2>/dev/null || true
}
trap cleanup EXIT

ROOT_FSTYPE="$(lsblk -no FSTYPE "${ROOT_PART}" | head -1)"
ESP_FSTYPE="$(lsblk -no FSTYPE "${ESP_PART}" | head -1)"
ROOT_UUID="$(lsblk -no UUID "${ROOT_PART}" | head -1)"

echo "    root=${ROOT_PART} (${ROOT_FSTYPE} UUID=${ROOT_UUID})"
echo "    esp=${ESP_PART} (${ESP_FSTYPE})"

[[ -n "${ROOT_UUID}" ]] || die "could not read root UUID"
case "${ESP_FSTYPE}" in
  vfat|fat|fat32|msdos|msdosfs) ;;
  *) die "ESP must be FAT/vfat, got: ${ESP_FSTYPE}" ;;
esac

# Mount root (btrfs @ when present)
if [[ "${ROOT_FSTYPE}" == "btrfs" ]]; then
  if mount -o subvol=/@ "${ROOT_PART}" "${MNT}" 2>/dev/null; then
    SUBVOL="@"
  elif mount -o subvol=@ "${ROOT_PART}" "${MNT}" 2>/dev/null; then
    SUBVOL="@"
  else
    mount "${ROOT_PART}" "${MNT}" || die "mount root failed"
    SUBVOL=""
  fi
else
  mount "${ROOT_PART}" "${MNT}" || die "mount root failed"
  SUBVOL=""
fi

mkdir -p "${MNT}/boot/efi"
mount "${ESP_PART}" "${MNT}/boot/efi" || die "mount ESP failed"

# Optional nested /boot subvolume (rare)
if [[ -f "${MNT}/etc/fstab" ]]; then
  if grep -qE '[[:space:]]/boot[[:space:]]' "${MNT}/etc/fstab"; then
    # /boot may already be under @; nothing to do unless separate device
    :
  fi
fi

[[ -r "${MNT}/boot/vmlinuz-linux" ]] || die "no ${MNT}/boot/vmlinuz-linux — install incomplete?"
[[ -r "${MNT}/boot/initramfs-linux.img" ]] || die "no initramfs-linux.img"

STAGE="${MNT}/boot/efi/EFI/EnigmarsOS"
mkdir -p "${STAGE}" "${MNT}/boot/efi/EFI/BOOT"

# Prefer the packaged sync helper when present on the installed system
if [[ -x "${MNT}/usr/share/enigmarsos/scripts/sync-esp-boot.sh" ]]; then
  echo "    Running target sync-esp-boot.sh via chroot..."
  # ESP already mounted at ${MNT}/boot/efi
  if arch-chroot "${MNT}" /usr/share/enigmarsos/scripts/sync-esp-boot.sh; then
    echo "==> EnigmarsOS: repair done via sync-esp-boot"
    exit 0
  fi
  echo "WARNING: sync-esp-boot failed; falling back to manual copy" >&2
fi

echo "    Copying kernel + initramfs to ESP..."
cp -a "${MNT}/boot/vmlinuz-linux" "${STAGE}/vmlinuz-linux"
cp -a "${MNT}/boot/initramfs-linux.img" "${STAGE}/initramfs-linux.img"
[[ -r "${MNT}/boot/initramfs-linux-fallback.img" ]] && \
  cp -a "${MNT}/boot/initramfs-linux-fallback.img" "${STAGE}/initramfs-linux-fallback.img"
[[ -r "${MNT}/boot/amd-ucode.img" ]] && cp -a "${MNT}/boot/amd-ucode.img" "${STAGE}/amd-ucode.img"
[[ -r "${MNT}/boot/intel-ucode.img" ]] && cp -a "${MNT}/boot/intel-ucode.img" "${STAGE}/intel-ucode.img"

# Ensure Limine EFI binary exists
if [[ -r "${MNT}/usr/share/limine/BOOTX64.EFI" ]]; then
  cp -a "${MNT}/usr/share/limine/BOOTX64.EFI" "${MNT}/boot/efi/EFI/BOOT/BOOTX64.EFI"
  cp -a "${MNT}/usr/share/limine/BOOTX64.EFI" "${STAGE}/BOOTX64.EFI"
elif [[ ! -f "${MNT}/boot/efi/EFI/BOOT/BOOTX64.EFI" && ! -f "${STAGE}/BOOTX64.EFI" ]]; then
  echo "WARNING: BOOTX64.EFI missing; copy from live system if boot still fails" >&2
  if [[ -r /usr/share/limine/BOOTX64.EFI ]]; then
    cp -a /usr/share/limine/BOOTX64.EFI "${MNT}/boot/efi/EFI/BOOT/BOOTX64.EFI"
    cp -a /usr/share/limine/BOOTX64.EFI "${STAGE}/BOOTX64.EFI"
  fi
fi

CMDLINE="root=UUID=${ROOT_UUID} rw quiet splash loglevel=3"
if [[ -n "${SUBVOL}" ]]; then
  CMDLINE="root=UUID=${ROOT_UUID} rootflags=subvol=/${SUBVOL} rw quiet splash loglevel=3"
fi
# Prefer fstab if more precise
if [[ -r "${MNT}/etc/fstab" ]]; then
  FSTAB_LINE="$(awk '$2=="/" && $1 ~ /^UUID=/ {print; exit}' "${MNT}/etc/fstab" || true)"
  if [[ -n "${FSTAB_LINE}" ]]; then
    # extract rootflags from options field if present
    opts="$(echo "${FSTAB_LINE}" | awk '{print $4}')"
    if echo "${opts}" | grep -q 'subvol='; then
      sv="$(echo "${opts}" | tr ',' '\n' | sed -n 's/^subvol=//p' | head -1)"
      sv="${sv#/}"
      [[ -n "${sv}" ]] && CMDLINE="root=UUID=${ROOT_UUID} rootflags=subvol=/${sv} rw quiet splash loglevel=3"
    fi
  fi
fi

UCODE_LINES=""
[[ -f "${STAGE}/intel-ucode.img" ]] && UCODE_LINES+="    module_path: boot():/EFI/EnigmarsOS/intel-ucode.img"$'\n'
[[ -f "${STAGE}/amd-ucode.img" ]] && UCODE_LINES+="    module_path: boot():/EFI/EnigmarsOS/amd-ucode.img"$'\n'

FALLBACK_MODULE="boot():/EFI/EnigmarsOS/initramfs-linux.img"
[[ -f "${STAGE}/initramfs-linux-fallback.img" ]] && \
  FALLBACK_MODULE="boot():/EFI/EnigmarsOS/initramfs-linux-fallback.img"

write_conf() {
  local dest="$1"
  cat >"${dest}" <<EOF
# EnigmarsOS Limine configuration (repaired)
# Kernels staged on ESP — Limine cannot read btrfs/ext4.
timeout: 5
default_entry: 1
interface_branding: EnigmarsOS
interface_branding_colour: 6
term_background: 000000

/+EnigmarsOS
//EnigmarsOS
    protocol: linux
    path: boot():/EFI/EnigmarsOS/vmlinuz-linux
${UCODE_LINES}    module_path: boot():/EFI/EnigmarsOS/initramfs-linux.img
    cmdline: ${CMDLINE}

//EnigmarsOS (fallback initramfs)
    protocol: linux
    path: boot():/EFI/EnigmarsOS/vmlinuz-linux
${UCODE_LINES}    module_path: ${FALLBACK_MODULE}
    cmdline: ${CMDLINE}

/+Advanced options
//Reboot
    protocol: reboot
//Shutdown
    protocol: shutdown
EOF
  echo "    wrote ${dest}"
}

write_conf "${MNT}/boot/efi/limine.conf"
write_conf "${MNT}/boot/efi/EFI/BOOT/limine.conf"
write_conf "${MNT}/boot/efi/EFI/EnigmarsOS/limine.conf"

sync
echo
echo "==> Repair complete."
echo "    Staged files:"
ls -lh "${STAGE}"
echo
echo "    cmdline: ${CMDLINE}"
echo "    Reboot (remove live USB) and select EnigmarsOS / EFI boot."
echo "    If firmware does not list EnigmarsOS, pick the disk's UEFI entry."
