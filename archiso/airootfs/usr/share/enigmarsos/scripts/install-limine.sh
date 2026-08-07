#!/usr/bin/env bash
# Install and configure Limine on the TARGET system (Calamares shellprocess, chrooted).
#
# Limine only supports FAT12/16/32 and ISO9660 for *reading files*.
# Kernel, initramfs, limine.conf, and limine-bios.sys must live on a FAT
# volume (the ESP on typical UEFI installs). Root may be btrfs/ext4/xfs.
#
# UEFI-first: never abort a UEFI install because limine bios-install needs
# a BIOS boot partition.
set -uo pipefail
# Note: not using set -e; optional steps must not kill the install.

echo "==> EnigmarsOS: install-limine"

die() {
  echo "ERROR: $*" >&2
  exit 1
}

is_fat() {
  case "${1:-}" in
    vfat|fat|fat32|msdos|msdosfs) return 0 ;;
    *) return 1 ;;
  esac
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

# --- Kernel present on the installed root? ---
[[ -r /boot/vmlinuz-linux ]] || die "/boot/vmlinuz-linux missing — seed-kernel should have run first"
[[ -r /boot/initramfs-linux.img ]] || die "/boot/initramfs-linux.img missing"

# --- ESP / FAT boot volume detection (must happen before path decisions) ---
ESP=""
for cand in /boot/efi /efi; do
  if mountpoint -q "${cand}" 2>/dev/null; then
    FST="$(findmnt -no FSTYPE "${cand}" 2>/dev/null || true)"
    if is_fat "${FST}" || [[ -z "${FST}" ]]; then
      ESP="${cand}"
      break
    fi
  fi
done
# Combined /boot as ESP (FAT)
if [[ -z "${ESP}" ]]; then
  if mountpoint -q /boot 2>/dev/null; then
    FST="$(findmnt -no FSTYPE /boot 2>/dev/null || true)"
    if is_fat "${FST}"; then
      ESP="/boot"
    fi
  fi
fi
[[ -n "${ESP}" ]] || ESP="/boot/efi"
mkdir -p "${ESP}" 2>/dev/null || true

ESP_FSTYPE="$(findmnt -no FSTYPE "${ESP}" 2>/dev/null || true)"
BOOT_FSTYPE="$(findmnt -no FSTYPE /boot 2>/dev/null || true)"
BOOT_UUID="$(findmnt -no UUID /boot 2>/dev/null || true)"

# Where Limine can actually read files from (FAT only).
# Staging dir on the ESP for kernel + initramfs when /boot is not FAT.
STAGE_DIR="${ESP}/EFI/EnigmarsOS"
mkdir -p "${STAGE_DIR}" "${ESP}/EFI/BOOT"

stage_to_esp() {
  local src="$1" dest_name="$2"
  if [[ -r "${src}" ]]; then
    install -Dm644 "${src}" "${STAGE_DIR}/${dest_name}" || die "failed to stage ${src} → ${STAGE_DIR}/${dest_name}"
    echo "    staged ${dest_name} ($(du -h "${STAGE_DIR}/${dest_name}" | awk '{print $1}'))"
    return 0
  fi
  return 1
}

# Limine path syntax is resource(arg):/path  — NOT uuid:arg:/path
# Prefer boot(): when conf + files share the ESP (UEFI default).
if is_fat "${BOOT_FSTYPE}" && [[ "$(findmnt -no TARGET /boot 2>/dev/null)" == "/boot" ]] \
   && { [[ "${ESP}" == "/boot" ]] || [[ "$(findmnt -no UUID "${ESP}" 2>/dev/null)" == "${BOOT_UUID}" ]]; }; then
  # /boot is already a FAT volume (possibly the ESP itself)
  CONF_DIR="/boot"
  if [[ "${ESP}" == "/boot" ]]; then
    KPATH="boot():/vmlinuz-linux"
    IPATH="boot():/initramfs-linux.img"
    FPATH="boot():/initramfs-linux-fallback.img"
    UCODE_AMD="boot():/amd-ucode.img"
    UCODE_INTEL="boot():/intel-ucode.img"
  else
    # Separate FAT /boot; conf may live on ESP → use uuid(FS-UUID)
    KPATH="uuid(${BOOT_UUID}):/vmlinuz-linux"
    IPATH="uuid(${BOOT_UUID}):/initramfs-linux.img"
    FPATH="uuid(${BOOT_UUID}):/initramfs-linux-fallback.img"
    UCODE_AMD="uuid(${BOOT_UUID}):/amd-ucode.img"
    UCODE_INTEL="uuid(${BOOT_UUID}):/intel-ucode.img"
  fi
  echo "    /boot is FAT — using kernel files in place"
else
  # /boot is btrfs/ext4/xfs (or not FAT). Stage onto ESP so Limine can read them.
  CONF_DIR="${ESP}"
  echo "    /boot fstype=${BOOT_FSTYPE:-unknown} is not FAT — staging kernel files onto ESP (${STAGE_DIR})"
  stage_to_esp /boot/vmlinuz-linux vmlinuz-linux || die "cannot stage vmlinuz-linux"
  stage_to_esp /boot/initramfs-linux.img initramfs-linux.img || die "cannot stage initramfs-linux.img"
  stage_to_esp /boot/initramfs-linux-fallback.img initramfs-linux-fallback.img || true
  stage_to_esp /boot/amd-ucode.img amd-ucode.img || true
  stage_to_esp /boot/intel-ucode.img intel-ucode.img || true

  # conf lives on ESP → boot(): resolves to that partition
  KPATH="boot():/EFI/EnigmarsOS/vmlinuz-linux"
  IPATH="boot():/EFI/EnigmarsOS/initramfs-linux.img"
  FPATH="boot():/EFI/EnigmarsOS/initramfs-linux-fallback.img"
  UCODE_AMD="boot():/EFI/EnigmarsOS/amd-ucode.img"
  UCODE_INTEL="boot():/EFI/EnigmarsOS/intel-ucode.img"
fi

echo "    root UUID=${ROOT_UUID} src=${ROOT_SRC} fstype=${ROOT_FSTYPE} subvol=${SUBVOL:-none}"
echo "    ESP=${ESP} (fstype=${ESP_FSTYPE:-?}) conf=${CONF_DIR}"
echo "    cmdline=${CMDLINE}"
echo "    kernel path=${KPATH}"

# --- Place Limine binaries ---
LIMINE_DATA="$(limine --print-datadir 2>/dev/null || echo /usr/share/limine)"

if [[ ! -f "${LIMINE_DATA}/BOOTX64.EFI" ]]; then
  die "BOOTX64.EFI not found in ${LIMINE_DATA}"
fi

install -Dm644 "${LIMINE_DATA}/BOOTX64.EFI" "${ESP}/EFI/BOOT/BOOTX64.EFI"
install -Dm644 "${LIMINE_DATA}/BOOTX64.EFI" "${ESP}/EFI/EnigmarsOS/BOOTX64.EFI"
if [[ -f "${LIMINE_DATA}/BOOTIA32.EFI" ]]; then
  install -Dm644 "${LIMINE_DATA}/BOOTIA32.EFI" "${ESP}/EFI/BOOT/BOOTIA32.EFI" || true
fi
if [[ -f "${LIMINE_DATA}/limine-bios.sys" ]]; then
  # limine-bios.sys must also live on a supported (FAT) FS
  install -Dm644 "${LIMINE_DATA}/limine-bios.sys" "${ESP}/limine-bios.sys" || true
  install -Dm644 "${LIMINE_DATA}/limine-bios.sys" "${ESP}/EFI/EnigmarsOS/limine-bios.sys" || true
  if [[ "${CONF_DIR}" != "${ESP}" ]] && is_fat "${BOOT_FSTYPE}"; then
    install -Dm644 "${LIMINE_DATA}/limine-bios.sys" "${CONF_DIR}/limine-bios.sys" || true
  fi
fi

# --- limine.conf ---
UCODE_LINES=""
if [[ -r /boot/intel-ucode.img ]] || [[ -r "${STAGE_DIR}/intel-ucode.img" ]]; then
  UCODE_LINES+="    module_path: ${UCODE_INTEL}"$'\n'
fi
if [[ -r /boot/amd-ucode.img ]] || [[ -r "${STAGE_DIR}/amd-ucode.img" ]]; then
  UCODE_LINES+="    module_path: ${UCODE_AMD}"$'\n'
fi

write_conf() {
  local dest="$1"
  mkdir -p "$(dirname "${dest}")"
  cat >"${dest}" <<EOF
# EnigmarsOS Limine configuration
# Kernel/initramfs must be on FAT (ESP). Root FS may be btrfs/ext4/xfs.
timeout: 5
default_entry: 1
interface_branding: EnigmarsOS
interface_branding_colour: 6
term_background: 000000

/+EnigmarsOS
//EnigmarsOS
    protocol: linux
    path: ${KPATH}
${UCODE_LINES}    module_path: ${IPATH}
    cmdline: ${CMDLINE}

//EnigmarsOS (fallback initramfs)
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

# UEFI Limine loads <EFI app path>/limine.conf first — write next to every .EFI.
write_conf "${ESP}/limine.conf"
write_conf "${ESP}/EFI/BOOT/limine.conf"
write_conf "${ESP}/EFI/EnigmarsOS/limine.conf"
# Keep a copy under CONF_DIR when it is a FAT /boot (human + BIOS scanning).
if [[ "${CONF_DIR}" != "${ESP}" ]] && is_fat "${BOOT_FSTYPE}"; then
  write_conf "${CONF_DIR}/limine.conf" || true
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
has_bios_boot_part() {
  local disk="$1"
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
      while read -r bootnum; do
        [[ -n "${bootnum}" ]] || continue
        efibootmgr -b "${bootnum}" -B >/dev/null 2>&1 || true
      done < <(efibootmgr 2>/dev/null | sed -n 's/^Boot\([0-9A-Fa-f]\+\).*EnigmarsOS.*/\1/p' || true)

      efibootmgr --create --disk "${PDISK}" --part "${PART}" \
        --label "EnigmarsOS" \
        --loader '\EFI\EnigmarsOS\BOOTX64.EFI' >/dev/null 2>&1 \
      || efibootmgr --create --disk "${PDISK}" --part "${PART}" \
        --label "EnigmarsOS" \
        --loader '\EFI\BOOT\BOOTX64.EFI' >/dev/null 2>&1 \
      || echo "WARNING: efibootmgr create failed (firmware may still boot EFI/BOOT/BOOTX64.EFI)" >&2
    fi
  fi
fi

# --- Final success check ---
if [[ ! -f "${ESP}/EFI/BOOT/BOOTX64.EFI" && ! -f "${ESP}/EFI/EnigmarsOS/BOOTX64.EFI" ]]; then
  die "Limine EFI binary missing under ${ESP}"
fi
if [[ ! -f "${ESP}/limine.conf" && ! -f "${ESP}/EFI/BOOT/limine.conf" ]]; then
  die "limine.conf was not written to ESP"
fi
if [[ ! -f "${STAGE_DIR}/vmlinuz-linux" ]] && [[ ! -f /boot/vmlinuz-linux ]]; then
  die "no staged or in-place kernel for Limine to load"
fi
# When we staged, require the staged kernel
if ! is_fat "${BOOT_FSTYPE}" || [[ "${ESP}" != "/boot" && "$(findmnt -no UUID "${ESP}" 2>/dev/null)" != "${BOOT_UUID}" ]]; then
  [[ -f "${STAGE_DIR}/vmlinuz-linux" ]] || die "staged vmlinuz-linux missing on ESP"
  [[ -f "${STAGE_DIR}/initramfs-linux.img" ]] || die "staged initramfs-linux.img missing on ESP"
fi

echo "==> EnigmarsOS: install-limine done (UEFI=${IS_UEFI})"
exit 0
