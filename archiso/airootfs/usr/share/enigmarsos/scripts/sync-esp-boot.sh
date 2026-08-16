#!/usr/bin/env bash
# Stage kernel/initramfs/ucode onto the ESP for Limine after package updates.
#
# Limine can only *read* FAT. On a typical EnigmarsOS install, /boot lives on
# btrfs (root) while the ESP is mounted at /boot/efi. pacman writes new kernels
# to /boot only; without this sync, Limine keeps booting the *old* kernel from
# the ESP after linux upgrades. That kernel has no matching modules → vfat fails
# → "Failed to mount /boot/efi" → emergency mode. UFW ("CLI Netfilter Manager")
# also fails for the same missing-modules reason.
#
# Safe to run: at install (after install-limine), from pacman hooks, or manually:
#   sudo /usr/share/enigmarsos/scripts/sync-esp-boot.sh
set -uo pipefail

echo "==> EnigmarsOS: sync-esp-boot"

is_fat() {
  case "${1:-}" in
    vfat|fat|fat32|msdos|msdosfs) return 0 ;;
    *) return 1 ;;
  esac
}

ensure_esp_mounted() {
  local cand fstab_dev
  for cand in /boot/efi /efi; do
    if mountpoint -q "${cand}" 2>/dev/null; then
      ESP="${cand}"
      return 0
    fi
  done

  # Prefer fstab mount so UUID/options stay correct
  if [[ -r /etc/fstab ]] && grep -qE '[[:space:]]/boot/efi[[:space:]]' /etc/fstab; then
    mkdir -p /boot/efi
    if mount /boot/efi 2>/dev/null; then
      ESP="/boot/efi"
      return 0
    fi
  fi
  if [[ -r /etc/fstab ]] && grep -qE '[[:space:]]/efi[[:space:]]' /etc/fstab; then
    mkdir -p /efi
    if mount /efi 2>/dev/null; then
      ESP="/efi"
      return 0
    fi
  fi

  # Last resort: PARTLABEL=EFI / fat partitions
  fstab_dev="$(lsblk -no PATH,PARTLABEL,FSTYPE 2>/dev/null | awk '$2=="EFI" && $3 ~ /vfat|fat/ {print $1; exit}')"
  if [[ -z "${fstab_dev}" ]]; then
    fstab_dev="$(lsblk -no PATH,FSTYPE,PARTTYPE 2>/dev/null | awk '$3 ~ /[Cc]12A7328|[Ee][Ff][Ii]/ && $2 ~ /vfat|fat/ {print $1; exit}')"
  fi
  if [[ -n "${fstab_dev}" && -b "${fstab_dev}" ]]; then
    mkdir -p /boot/efi
    if mount -t vfat "${fstab_dev}" /boot/efi 2>/dev/null; then
      ESP="/boot/efi"
      return 0
    fi
  fi

  echo "ERROR: could not mount ESP (/boot/efi). Fix fstab or mount manually, then re-run." >&2
  return 1
}

# --- Locate ESP ---
ESP=""
if mountpoint -q /boot 2>/dev/null && is_fat "$(findmnt -no FSTYPE /boot 2>/dev/null || true)"; then
  # Combined FAT /boot (rare) — nothing to stage
  echo "    /boot is FAT — kernels already where Limine can read them; nothing to stage"
  exit 0
fi

ensure_esp_mounted || exit 1

ESP_FSTYPE="$(findmnt -no FSTYPE "${ESP}" 2>/dev/null || true)"
if ! is_fat "${ESP_FSTYPE}"; then
  echo "ERROR: ${ESP} is not FAT/vfat (got: ${ESP_FSTYPE:-unknown})" >&2
  exit 1
fi

STAGE_DIR="${ESP}/EFI/EnigmarsOS"
mkdir -p "${STAGE_DIR}" "${ESP}/EFI/BOOT"

# Free space warning (need room for kernel + initramfs ~200M+)
AVAIL_KB="$(df -Pk "${ESP}" 2>/dev/null | awk 'NR==2 {print $4}')"
if [[ -n "${AVAIL_KB}" && "${AVAIL_KB}" -lt 200000 ]]; then
  echo "WARNING: ESP has less than ~200MB free (${AVAIL_KB}K). Updates may fail to stage." >&2
fi

stage_one() {
  local src="$1" dest="$2"
  if [[ -r "${src}" ]]; then
    # Atomic-ish replace on FAT
    install -Dm644 "${src}" "${STAGE_DIR}/${dest}.new" || return 1
    mv -f "${STAGE_DIR}/${dest}.new" "${STAGE_DIR}/${dest}" || return 1
    echo "    staged ${dest} ($(du -h "${STAGE_DIR}/${dest}" | awk '{print $1}'))"
    return 0
  fi
  return 1
}

# Discover kernels: /boot/vmlinuz-<pkg>
shopt -s nullglob
kernels=(/boot/vmlinuz-*)
if ((${#kernels[@]} == 0)); then
  echo "ERROR: no /boot/vmlinuz-* found — install a kernel package first" >&2
  exit 1
fi

STAGED_PKGS=()
for vmlinuz in "${kernels[@]}"; do
  pkg="${vmlinuz##*/vmlinuz-}"
  [[ -n "${pkg}" ]] || continue
  echo "    kernel package: ${pkg}"
  stage_one "/boot/vmlinuz-${pkg}" "vmlinuz-${pkg}" || {
    echo "ERROR: failed to stage vmlinuz-${pkg}" >&2
    exit 1
  }
  stage_one "/boot/initramfs-${pkg}.img" "initramfs-${pkg}.img" || {
    echo "ERROR: failed to stage initramfs-${pkg}.img (run mkinitcpio -P?)" >&2
    exit 1
  }
  stage_one "/boot/initramfs-${pkg}-fallback.img" "initramfs-${pkg}-fallback.img" || true
  STAGED_PKGS+=("${pkg}")
done

stage_one /boot/amd-ucode.img amd-ucode.img || true
stage_one /boot/intel-ucode.img intel-ucode.img || true

# Default Limine entry: EnigmarsOS kernel, then stock Arch linux, then others
sorted_pkgs=()
for p in "${STAGED_PKGS[@]}"; do
  [[ "${p}" == "linux-enigmarsos" ]] && sorted_pkgs+=("${p}")
done
for p in "${STAGED_PKGS[@]}"; do
  [[ "${p}" == "linux" ]] && sorted_pkgs+=("${p}")
done
for p in "${STAGED_PKGS[@]}"; do
  [[ "${p}" != "linux-enigmarsos" && "${p}" != "linux" ]] && sorted_pkgs+=("${p}")
done

# Root cmdline (same logic as install-limine)
ROOT_UUID="$(findmnt -no UUID / 2>/dev/null || true)"
ROOT_FSTYPE="$(findmnt -no FSTYPE / 2>/dev/null || true)"
ROOT_OPTS="$(findmnt -no OPTIONS / 2>/dev/null || true)"
if [[ -z "${ROOT_UUID}" && -r /etc/fstab ]]; then
  ROOT_UUID="$(awk '$2=="/" && $1 ~ /^UUID=/ {sub(/^UUID=/,"",$1); print $1; exit}' /etc/fstab || true)"
fi
if [[ -z "${ROOT_UUID}" ]]; then
  echo "WARNING: could not determine root UUID; leaving existing limine.conf cmdline if any" >&2
fi

CMDLINE=""
if [[ -n "${ROOT_UUID}" ]]; then
  CMDLINE="root=UUID=${ROOT_UUID} rw quiet splash loglevel=3"
  if [[ "${ROOT_FSTYPE}" == "btrfs" ]]; then
    SUBVOL="$(echo "${ROOT_OPTS}" | tr ',' '\n' | sed -n 's/^subvol=//p' | head -1)"
    SUBVOL="${SUBVOL#/}"
    if [[ -n "${SUBVOL}" && "${SUBVOL}" != "/" ]]; then
      CMDLINE="root=UUID=${ROOT_UUID} rootflags=subvol=/${SUBVOL} rw quiet splash loglevel=3"
    fi
  fi
  if [[ -r /etc/crypttab ]]; then
    CRYPT_UUID="$(awk '!/^#/ && NF {
      for (i = 1; i <= NF; i++)
        if ($i ~ /^UUID=/) { sub(/^UUID=/, "", $i); print $i; exit }
    }' /etc/crypttab || true)"
    if [[ -n "${CRYPT_UUID}" ]]; then
      CMDLINE="rd.luks.uuid=${CRYPT_UUID} ${CMDLINE}"
    fi
  fi
fi

UCODE_BLOCK=""
if [[ -r "${STAGE_DIR}/intel-ucode.img" ]]; then
  UCODE_BLOCK+="    module_path: boot():/EFI/EnigmarsOS/intel-ucode.img"$'\n'
fi
if [[ -r "${STAGE_DIR}/amd-ucode.img" ]]; then
  UCODE_BLOCK+="    module_path: boot():/EFI/EnigmarsOS/amd-ucode.img"$'\n'
fi

# Build menu entries
ENTRIES=""
for pkg in "${sorted_pkgs[@]}"; do
  label="EnigmarsOS"
  [[ "${pkg}" != "linux" ]] && label="EnigmarsOS (${pkg})"
  ENTRIES+="//${label}
    protocol: linux
    path: boot():/EFI/EnigmarsOS/vmlinuz-${pkg}
${UCODE_BLOCK}    module_path: boot():/EFI/EnigmarsOS/initramfs-${pkg}.img
    cmdline: ${CMDLINE}

"
  if [[ -r "${STAGE_DIR}/initramfs-${pkg}-fallback.img" ]]; then
    ENTRIES+="//${label} (fallback initramfs)
    protocol: linux
    path: boot():/EFI/EnigmarsOS/vmlinuz-${pkg}
${UCODE_BLOCK}    module_path: boot():/EFI/EnigmarsOS/initramfs-${pkg}-fallback.img
    cmdline: ${CMDLINE}

"
  fi
done

write_conf() {
  local dest="$1"
  mkdir -p "$(dirname "${dest}")"
  cat >"${dest}" <<EOF
# EnigmarsOS Limine configuration (managed by sync-esp-boot)
# Regenerated after kernel/initramfs updates — do not hand-edit permanently.
timeout: 5
default_entry: 1
interface_branding: EnigmarsOS
interface_branding_colour: 6
term_background: 000000

/+EnigmarsOS
${ENTRIES}/+Advanced options
//Reboot
    protocol: reboot
//Shutdown
    protocol: shutdown
EOF
  echo "    wrote ${dest}"
}

if [[ -n "${CMDLINE}" ]]; then
  write_conf "${ESP}/limine.conf"
  write_conf "${ESP}/EFI/BOOT/limine.conf"
  write_conf "${ESP}/EFI/EnigmarsOS/limine.conf"
else
  echo "    skipped limine.conf rewrite (no root UUID); kernels still staged"
fi

# Keep limine EFI binary present if package updated it
if command -v limine >/dev/null 2>&1; then
  LIMINE_DATA="$(limine --print-datadir 2>/dev/null || echo /usr/share/limine)"
  if [[ -f "${LIMINE_DATA}/BOOTX64.EFI" ]]; then
    install -Dm644 "${LIMINE_DATA}/BOOTX64.EFI" "${ESP}/EFI/BOOT/BOOTX64.EFI" || true
    install -Dm644 "${LIMINE_DATA}/BOOTX64.EFI" "${ESP}/EFI/EnigmarsOS/BOOTX64.EFI" || true
  fi
fi

echo "==> EnigmarsOS: sync-esp-boot done (ESP=${ESP}, pkgs=${sorted_pkgs[*]})"
exit 0
