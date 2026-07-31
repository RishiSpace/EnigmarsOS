#!/usr/bin/env bash
# Install and configure Limine on the TARGET system (Calamares shellprocess, chrooted).
# UEFI-first: never abort a UEFI install because limine bios-install needs a BIOS boot partition.
set -uo pipefail
# Note: not using set -e; optional steps must not kill the install.

echo "==> EnigmaOS: install-limine"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

if ! command -v limine >/dev/null 2>&1; then
  die "limine not installed in target"
fi

IS_UEFI=0
if [[ -d /sys/firmware/efi ]]; then
  IS_UEFI=1
  echo "    firmware: UEFI"
else
  echo "    firmware: BIOS/legacy"
fi

# --- Root filesystem identity ---
ROOT_SRC="$(findmnt -no SOURCE / 2>/dev/null || true)"
ROOT_UUID="$(findmnt -no UUID / 2>/dev/null || true)"
ROOT_FSTYPE="$(findmnt -no FSTYPE / 2>/dev/null || true)"
ROOT_OPTS="$(findmnt -no OPTIONS / 2>/dev/null || true)"

if [[ -z "${ROOT_UUID}" ]]; then
  ROOT_UUID="$(awk '$2=="/" && $1 ~ /^UUID=/ {sub(/^UUID=/,"",$1); print $1; exit}' /etc/fstab || true)"
fi
[[ -n "${ROOT_UUID}" ]] || die "could not determine root UUID"

CMDLINE="root=UUID=${ROOT_UUID} rw quiet splash loglevel=3"
SUBVOL=""
if [[ "${ROOT_FSTYPE}" == "btrfs" ]]; then
  SUBVOL="$(echo "${ROOT_OPTS}" | tr ',' '\n' | sed -n 's/^subvol=//p' | head -1)"
  # strip leading slash for consistency: /@ -> @
  SUBVOL="${SUBVOL#/}"
  if [[ -n "${SUBVOL}" && "${SUBVOL}" != "/" ]]; then
    CMDLINE="root=UUID=${ROOT_UUID} rootflags=subvol=/${SUBVOL} rw quiet splash loglevel=3"
  fi
fi

if [[ "${ROOT_SRC}" == /dev/mapper/* ]] && [[ -r /etc/crypttab ]]; then
  CRYPT_UUID="$(awk '!/^#/ && NF {
    for (i = 1; i <= NF; i++)
      if ($i ~ /^UUID=/) { sub(/^UUID=/, "", $i); print $i; exit }
  }' /etc/crypttab || true)"
  if [[ -n "${CRYPT_UUID}" ]]; then
    CMDLINE="rd.luks.uuid=${CRYPT_UUID} ${CMDLINE}"
  fi
fi

# --- Kernel present? ---
[[ -r /boot/vmlinuz-linux ]] || die "/boot/vmlinuz-linux missing — seed-kernel should have run first"

# Paths as seen on the *partition*, not the mount (btrfs subvol matters).
# If root is btrfs subvol=@ and kernels live at /boot on that mount, on-disk path is /@/boot/...
fs_path() {
  # $1 = path as mounted (absolute)
  local p="$1"
  if [[ "${ROOT_FSTYPE}" == "btrfs" && -n "${SUBVOL}" && "${SUBVOL}" != "/" ]]; then
    # mounted at / so /boot/foo -> /@/boot/foo (SUBVOL without leading slash)
    if [[ "${p}" == /boot/* || "${p}" == /boot ]]; then
      echo "/${SUBVOL}${p}"
      return
    fi
  fi
  echo "${p}"
}

BOOT_UUID="$(findmnt -no UUID /boot 2>/dev/null || true)"
BOOT_FSTYPE="$(findmnt -no FSTYPE /boot 2>/dev/null || true)"
BOOT_OPTS="$(findmnt -no OPTIONS /boot 2>/dev/null || true)"

if [[ -n "${BOOT_UUID}" && "${BOOT_UUID}" != "${ROOT_UUID}" ]]; then
  # Separate /boot partition
  KPATH="uuid:${BOOT_UUID}:/vmlinuz-linux"
  IPATH="uuid:${BOOT_UUID}:/initramfs-linux.img"
  FPATH="uuid:${BOOT_UUID}:/initramfs-linux-fallback.img"
  UCODE_AMD="uuid:${BOOT_UUID}:/amd-ucode.img"
  UCODE_INTEL="uuid:${BOOT_UUID}:/intel-ucode.img"
  CONF_DIR="/boot"
else
  # /boot on root filesystem
  KPATH="uuid:${ROOT_UUID}:$(fs_path /boot/vmlinuz-linux)"
  IPATH="uuid:${ROOT_UUID}:$(fs_path /boot/initramfs-linux.img)"
  FPATH="uuid:${ROOT_UUID}:$(fs_path /boot/initramfs-linux-fallback.img)"
  UCODE_AMD="uuid:${ROOT_UUID}:$(fs_path /boot/amd-ucode.img)"
  UCODE_INTEL="uuid:${ROOT_UUID}:$(fs_path /boot/intel-ucode.img)"
  CONF_DIR="/boot"
fi

# --- ESP detection ---
ESP=""
for cand in /boot/efi /efi; do
  if mountpoint -q "${cand}" 2>/dev/null; then
    FST="$(findmnt -no FSTYPE "${cand}" 2>/dev/null || true)"
    if [[ "${FST}" == "vfat" || "${FST}" == "fat" || "${FST}" == "msdos" || -z "${FST}" ]]; then
      ESP="${cand}"
      break
    fi
  fi
done
# Fallback: combined /boot ESP
if [[ -z "${ESP}" ]]; then
  if mountpoint -q /boot 2>/dev/null; then
    FST="$(findmnt -no FSTYPE /boot 2>/dev/null || true)"
    if [[ "${FST}" == "vfat" || "${FST}" == "fat" || "${FST}" == "msdos" ]]; then
      ESP="/boot"
    fi
  fi
fi
[[ -n "${ESP}" ]] || ESP="/boot/efi"
mkdir -p "${ESP}" 2>/dev/null || true

echo "    root UUID=${ROOT_UUID} src=${ROOT_SRC} fstype=${ROOT_FSTYPE} subvol=${SUBVOL:-none}"
echo "    ESP=${ESP} conf=${CONF_DIR}"
echo "    cmdline=${CMDLINE}"
echo "    kernel path=${KPATH}"

# --- Place Limine binaries ---
LIMINE_DATA="$(limine --print-datadir 2>/dev/null || echo /usr/share/limine)"
mkdir -p "${ESP}/EFI/BOOT" "${ESP}/EFI/EnigmaOS" "${CONF_DIR}"

if [[ ! -f "${LIMINE_DATA}/BOOTX64.EFI" ]]; then
  die "BOOTX64.EFI not found in ${LIMINE_DATA}"
fi

install -Dm644 "${LIMINE_DATA}/BOOTX64.EFI" "${ESP}/EFI/BOOT/BOOTX64.EFI"
install -Dm644 "${LIMINE_DATA}/BOOTX64.EFI" "${ESP}/EFI/EnigmaOS/BOOTX64.EFI"
if [[ -f "${LIMINE_DATA}/BOOTIA32.EFI" ]]; then
  install -Dm644 "${LIMINE_DATA}/BOOTIA32.EFI" "${ESP}/EFI/BOOT/BOOTIA32.EFI" || true
fi
if [[ -f "${LIMINE_DATA}/limine-bios.sys" ]]; then
  install -Dm644 "${LIMINE_DATA}/limine-bios.sys" "${CONF_DIR}/limine-bios.sys" || true
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

write_conf() {
  local dest="$1"
  cat >"${dest}" <<EOF
# EnigmaOS Limine configuration
timeout: 5
default_entry: 1
interface_branding: EnigmaOS
interface_branding_colour: 6
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
  echo "    wrote ${dest}"
}

write_conf "${CONF_DIR}/limine.conf"
# Limine (UEFI) looks next to the .EFI file as well
if [[ "${ESP}" != "${CONF_DIR}" ]]; then
  write_conf "${ESP}/limine.conf" || true
  write_conf "${ESP}/EFI/BOOT/limine.conf" || true
  write_conf "${ESP}/EFI/EnigmaOS/limine.conf" || true
fi

parent_disk() {
  local src="$1"
  local pk pk2
  [[ -n "${src}" ]] || return 0
  pk="$(lsblk -no PKNAME "${src}" 2>/dev/null | awk 'NF{print; exit}')"
  if [[ -n "${pk}" ]]; then
    pk2="$(lsblk -no PKNAME "/dev/${pk}" 2>/dev/null | awk 'NF{print; exit}')"
    if [[ -n "${pk2}" ]]; then
      echo "/dev/${pk2}"
    else
      echo "/dev/${pk}"
    fi
  fi
}

# --- BIOS embed: ONLY on non-UEFI, or when a BIOS boot partition exists ---
# GPT + UEFI without a BIOS boot (EF02) partition always fails limine bios-install.
has_bios_boot_part() {
  local disk="$1"
  # Partition type GUID for BIOS boot
  lsblk -no PARTTYPE "${disk}" 2>/dev/null | grep -qi '21686148-6449-6e6f-744e-656564454649'
}

DISK=""
if [[ -n "${ROOT_SRC}" ]]; then
  DISK="$(parent_disk "${ROOT_SRC}" || true)"
fi
if [[ -z "${DISK}" || ! -b "${DISK}" ]]; then
  ESP_SRC="$(findmnt -no SOURCE "${ESP}" 2>/dev/null || true)"
  DISK="$(parent_disk "${ESP_SRC}" || true)"
fi

if [[ ${IS_UEFI} -eq 1 ]]; then
  if [[ -n "${DISK}" && -b "${DISK}" ]] && has_bios_boot_part "${DISK}"; then
    echo "    UEFI + BIOS boot partition present — running limine bios-install ${DISK}"
    limine bios-install "${DISK}" || \
      echo "WARNING: limine bios-install failed (continuing; UEFI files already installed)" >&2
  else
    echo "    UEFI install: skipping limine bios-install (no BIOS boot partition — expected on GPT/UEFI)"
  fi
else
  if [[ -n "${DISK}" && -b "${DISK}" ]]; then
    echo "    BIOS install: limine bios-install ${DISK}"
    if ! limine bios-install "${DISK}"; then
      echo "WARNING: limine bios-install failed on ${DISK}" >&2
      # Still not fatal if we somehow have hybrid; for pure BIOS this is bad but
      # leave EFI files and conf in place for recovery.
    fi
  else
    echo "WARNING: could not determine disk for limine bios-install" >&2
  fi
fi

# --- UEFI NVRAM entry (best effort, never fatal) ---
if [[ ${IS_UEFI} -eq 1 ]] && command -v efibootmgr >/dev/null 2>&1; then
  ESP_SRC="$(findmnt -no SOURCE "${ESP}" 2>/dev/null || true)"
  if [[ -n "${ESP_SRC}" ]]; then
    PART="$(lsblk -no PARTNUM "${ESP_SRC}" 2>/dev/null | awk 'NF{print; exit}')"
    PDISK="$(parent_disk "${ESP_SRC}" || true)"
    if [[ -n "${PDISK}" && -n "${PART}" ]]; then
      echo "    efibootmgr: disk=${PDISK} part=${PART}"
      # Remove any previous EnigmaOS entry labels (best effort)
      while read -r bootnum; do
        [[ -n "${bootnum}" ]] || continue
        efibootmgr -b "${bootnum}" -B >/dev/null 2>&1 || true
      done < <(efibootmgr 2>/dev/null | sed -n 's/^Boot\([0-9A-Fa-f]\+\).*EnigmaOS.*/\1/p' || true)

      efibootmgr --create --disk "${PDISK}" --part "${PART}" \
        --label "EnigmaOS" \
        --loader '\EFI\EnigmaOS\BOOTX64.EFI' >/dev/null 2>&1 \
      || efibootmgr --create --disk "${PDISK}" --part "${PART}" \
        --label "EnigmaOS" \
        --loader '\EFI\BOOT\BOOTX64.EFI' >/dev/null 2>&1 \
      || echo "WARNING: efibootmgr create failed (firmware may still boot EFI/BOOT/BOOTX64.EFI)" >&2
    fi
  fi
fi

# --- Final success check: UEFI needs EFI binary + conf; BIOS needs bios-install success ideally ---
if [[ ! -f "${ESP}/EFI/BOOT/BOOTX64.EFI" && ! -f "${ESP}/EFI/EnigmaOS/BOOTX64.EFI" ]]; then
  die "Limine EFI binary missing under ${ESP}"
fi
if [[ ! -f "${CONF_DIR}/limine.conf" && ! -f "${ESP}/limine.conf" ]]; then
  die "limine.conf was not written"
fi

echo "==> EnigmaOS: install-limine done (UEFI=${IS_UEFI})"
exit 0
