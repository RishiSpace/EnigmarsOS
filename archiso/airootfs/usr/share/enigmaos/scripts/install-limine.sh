#!/usr/bin/env bash
# Install and configure Limine on the TARGET system (Calamares shellprocess, chrooted).
set -euo pipefail

echo "==> EnigmaOS: install-limine"

if ! command -v limine >/dev/null 2>&1; then
  echo "ERROR: limine not installed in target" >&2
  exit 1
fi

# --- Root filesystem identity ---
ROOT_SRC="$(findmnt -no SOURCE / 2>/dev/null || true)"
ROOT_UUID="$(findmnt -no UUID / 2>/dev/null || true)"
ROOT_FSTYPE="$(findmnt -no FSTYPE / 2>/dev/null || true)"
ROOT_OPTS="$(findmnt -no OPTIONS / 2>/dev/null || true)"

if [[ -z "${ROOT_UUID}" ]]; then
  # Fallback via fstab
  ROOT_UUID="$(awk '$2=="/" && $1 ~ /^UUID=/ {sub(/^UUID=/,"",$1); print $1; exit}' /etc/fstab || true)"
fi
if [[ -z "${ROOT_UUID}" ]]; then
  echo "ERROR: could not determine root UUID" >&2
  findmnt / || true
  cat /etc/fstab || true
  exit 1
fi

CMDLINE="root=UUID=${ROOT_UUID} rw quiet splash loglevel=3"

if [[ "${ROOT_FSTYPE}" == "btrfs" ]]; then
  SUBVOL="$(echo "${ROOT_OPTS}" | tr ',' '\n' | sed -n 's/^subvol=//p' | head -1)"
  if [[ -n "${SUBVOL}" && "${SUBVOL}" != "/" ]]; then
    CMDLINE="root=UUID=${ROOT_UUID} rootflags=subvol=${SUBVOL} rw quiet splash loglevel=3"
  fi
fi

# LUKS: if root is on a mapper device, add cryptdevice hints when possible
if [[ "${ROOT_SRC}" == /dev/mapper/* ]] && [[ -r /etc/crypttab ]]; then
  # Prefer rd.luks.uuid if crypttab has UUID=
  CRYPT_UUID="$(awk '!/^#/ && NF { for(i=1;i<=NF;i++) if($i ~ /^UUID=/) { sub(/^UUID=/,"",$i); print $i; exit } }' /etc/crypttab || true)"
  if [[ -n "${CRYPT_UUID}" ]]; then
    CMDLINE="rd.luks.uuid=${CRYPT_UUID} ${CMDLINE}"
  fi
fi

# --- Kernel location ---
KERNEL_PATH="/boot/vmlinuz-linux"
INITRD_PATH="/boot/initramfs-linux.img"
FALLBACK_PATH="/boot/initramfs-linux-fallback.img"

if [[ ! -r "${KERNEL_PATH}" ]]; then
  echo "ERROR: ${KERNEL_PATH} missing — seed-kernel should have run first" >&2
  ls -la /boot || true
  exit 1
fi

# If /boot is its own mount, limine paths are relative to that volume without /boot prefix
BOOT_UUID="$(findmnt -no UUID /boot 2>/dev/null || true)"
if [[ -n "${BOOT_UUID}" && "${BOOT_UUID}" != "${ROOT_UUID}" ]]; then
  KPATH="uuid:${BOOT_UUID}:/vmlinuz-linux"
  IPATH="uuid:${BOOT_UUID}:/initramfs-linux.img"
  FPATH="uuid:${BOOT_UUID}:/initramfs-linux-fallback.img"
  UCODE_AMD="uuid:${BOOT_UUID}:/amd-ucode.img"
  UCODE_INTEL="uuid:${BOOT_UUID}:/intel-ucode.img"
  CONF_DIR="/boot"
else
  KPATH="uuid:${ROOT_UUID}:/boot/vmlinuz-linux"
  IPATH="uuid:${ROOT_UUID}:/boot/initramfs-linux.img"
  FPATH="uuid:${ROOT_UUID}:/boot/initramfs-linux-fallback.img"
  UCODE_AMD="uuid:${ROOT_UUID}:/boot/amd-ucode.img"
  UCODE_INTEL="uuid:${ROOT_UUID}:/boot/intel-ucode.img"
  CONF_DIR="/boot"
fi

# --- ESP detection ---
ESP=""
for cand in /boot/efi /efi /boot; do
  if mountpoint -q "${cand}" 2>/dev/null || [[ "${cand}" == "/boot" && -d "${cand}" ]]; then
    # Prefer a real vfat ESP when present
    if [[ "${cand}" == "/boot" ]]; then
      ESP="/boot"
      break
    fi
    FST="$(findmnt -no FSTYPE "${cand}" 2>/dev/null || true)"
    if [[ "${FST}" == "vfat" || "${FST}" == "fat" || "${FST}" == "msdos" || -z "${FST}" ]]; then
      ESP="${cand}"
      break
    fi
  fi
done
[[ -n "${ESP}" ]] || ESP="/boot"

echo "    root UUID=${ROOT_UUID} src=${ROOT_SRC}"
echo "    ESP=${ESP} conf=${CONF_DIR}"
echo "    cmdline=${CMDLINE}"

# --- Place Limine binaries ---
LIMINE_DATA="$(limine --print-datadir 2>/dev/null || echo /usr/share/limine)"
mkdir -p "${ESP}/EFI/BOOT" "${ESP}/EFI/EnigmaOS" "${CONF_DIR}"

if [[ -f "${LIMINE_DATA}/BOOTX64.EFI" ]]; then
  install -Dm644 "${LIMINE_DATA}/BOOTX64.EFI" "${ESP}/EFI/BOOT/BOOTX64.EFI"
  install -Dm644 "${LIMINE_DATA}/BOOTX64.EFI" "${ESP}/EFI/EnigmaOS/BOOTX64.EFI"
fi
if [[ -f "${LIMINE_DATA}/BOOTIA32.EFI" ]]; then
  install -Dm644 "${LIMINE_DATA}/BOOTIA32.EFI" "${ESP}/EFI/BOOT/BOOTIA32.EFI" || true
fi
if [[ -f "${LIMINE_DATA}/limine-bios.sys" ]]; then
  # BIOS stage file must be reachable; keep on both /boot and ESP when distinct
  install -Dm644 "${LIMINE_DATA}/limine-bios.sys" "${CONF_DIR}/limine-bios.sys"
  if [[ "${ESP}" != "${CONF_DIR}" ]]; then
    install -Dm644 "${LIMINE_DATA}/limine-bios.sys" "${ESP}/limine-bios.sys" || true
  fi
fi

# --- limine.conf ---
UCODE_LINES=""
if [[ -r /boot/intel-ucode.img ]]; then
  UCODE_LINES+="    module_path: ${UCODE_INTEL}"$'\n'
fi
if [[ -r /boot/amd-ucode.img ]]; then
  UCODE_LINES+="    module_path: ${UCODE_AMD}"$'\n'
fi

cat >"${CONF_DIR}/limine.conf" <<EOF
# EnigmaOS Limine configuration
timeout: 5
default_entry: 1
interface_branding: EnigmaOS
interface_branding_colour: 6
wallpaper_style: stretched
term_background: 000000

/+EnigmaOS
//EnigmaOS
    protocol: linux
    path: ${KPATH}
${UCODE_LINES}    module_path: ${IPATH}
    cmdline: ${CMDLINE}

//EnigmaOS (fallback initramfs)
    protocol: linux
    path: ${KPATH}
${UCODE_LINES}    module_path: ${FPATH}
    cmdline: ${CMDLINE}

/+Advanced options
//Reboot
    protocol: reboot
//Shutdown
    protocol: shutdown
EOF

# Also place conf next to the EFI binary when ESP is separate (Limine searches there)
if [[ "${ESP}" != "${CONF_DIR}" ]]; then
  install -Dm644 "${CONF_DIR}/limine.conf" "${ESP}/limine.conf" || true
  install -Dm644 "${CONF_DIR}/limine.conf" "${ESP}/EFI/BOOT/limine.conf" || true
  install -Dm644 "${CONF_DIR}/limine.conf" "${ESP}/EFI/EnigmaOS/limine.conf" || true
fi

# --- BIOS embed ---
# Derive whole-disk node from root (or from ESP) for limine bios-install
parent_disk() {
  local src="$1"
  local pk
  # Resolve mapper → underlying
  if [[ "${src}" == /dev/mapper/* ]] || [[ "${src}" == /dev/dm-* ]]; then
    pk="$(lsblk -no PKNAME "${src}" 2>/dev/null | tail -1)"
    if [[ -n "${pk}" ]]; then
      # walk up once more for partitions
      if [[ -b "/dev/${pk}" ]]; then
        local pk2
        pk2="$(lsblk -no PKNAME "/dev/${pk}" 2>/dev/null | tail -1)"
        if [[ -n "${pk2}" ]]; then
          echo "/dev/${pk2}"
          return
        fi
        echo "/dev/${pk}"
        return
      fi
    fi
  fi
  pk="$(lsblk -no PKNAME "${src}" 2>/dev/null | head -1)"
  if [[ -n "${pk}" ]]; then
    echo "/dev/${pk}"
    return
  fi
  # Already a disk?
  if [[ -b "${src}" ]] && [[ ! "${src}" =~ [0-9]$ ]] && [[ ! "${src}" =~ p[0-9]+$ ]]; then
    echo "${src}"
  fi
}

DISK=""
if [[ -n "${ROOT_SRC}" ]]; then
  DISK="$(parent_disk "${ROOT_SRC}" || true)"
fi
if [[ -z "${DISK}" || ! -b "${DISK}" ]]; then
  ESP_SRC="$(findmnt -no SOURCE "${ESP}" 2>/dev/null || true)"
  if [[ -n "${ESP_SRC}" ]]; then
    DISK="$(parent_disk "${ESP_SRC}" || true)"
  fi
fi

if [[ -n "${DISK}" && -b "${DISK}" ]]; then
  echo "    limine bios-install ${DISK}"
  limine bios-install "${DISK}" || {
    echo "WARNING: limine bios-install failed on ${DISK} (UEFI-only installs can ignore this)" >&2
  }
else
  echo "WARNING: could not determine install disk for BIOS limine (UEFI-only is fine)" >&2
fi

# --- UEFI NVRAM entry (best effort) ---
if command -v efibootmgr >/dev/null 2>&1 && [[ -d /sys/firmware/efi ]]; then
  ESP_SRC="$(findmnt -no SOURCE "${ESP}" 2>/dev/null || true)"
  if [[ -n "${ESP_SRC}" ]]; then
    PART="$(lsblk -no PARTNUM "${ESP_SRC}" 2>/dev/null | head -1)"
    PDISK="$(parent_disk "${ESP_SRC}" || true)"
    if [[ -n "${PDISK}" && -n "${PART}" ]]; then
      efibootmgr -b 0000 -B 2>/dev/null || true
      efibootmgr --create --disk "${PDISK}" --part "${PART}" \
        --label "EnigmaOS" \
        --loader '\EFI\EnigmaOS\BOOTX64.EFI' || \
      efibootmgr --create --disk "${PDISK}" --part "${PART}" \
        --label "EnigmaOS" \
        --loader '\EFI\BOOT\BOOTX64.EFI' || true
    fi
  fi
fi

echo "==> EnigmaOS: install-limine done"
