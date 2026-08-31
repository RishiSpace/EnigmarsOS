#!/usr/bin/env bash
# Runs inside the TARGET root via Calamares shellprocess (chrooted).
# Rewrites live archiso presets to a normal installed-system preset.
set -euo pipefail

echo "==> EnigmarsOS: fix-mkinitcpio"

rm -f /etc/mkinitcpio.conf.d/archiso.conf
rm -f /etc/mkinitcpio.d/*.preset.pacnew 2>/dev/null || true

write_preset() {
  local pkg="$1"
  local kver="/boot/vmlinuz-${pkg}"
  [[ -r "${kver}" ]] || return 0
  cat >"/etc/mkinitcpio.d/${pkg}.preset" <<EOF
# mkinitcpio preset file for the '${pkg}' package on EnigmarsOS (installed system)

ALL_config="/etc/mkinitcpio.conf"
ALL_kver="${kver}"

PRESETS=('default' 'fallback')

default_image="/boot/initramfs-${pkg}.img"

fallback_image="/boot/initramfs-${pkg}-fallback.img"
fallback_options="-S autodetect"
EOF
}

write_preset linux-enigmarsos
write_preset linux

if [[ ! -f /etc/mkinitcpio.conf ]]; then
  cat >/etc/mkinitcpio.conf <<'EOF'
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)
COMPRESSION="zstd"
EOF
fi

# Drop MODULES mkinitcpio cannot resolve. Arch's calamares initcpiocfg still
# injects crc32c-intel on Intel+btrfs; that .ko was merged into the generic
# CRC library in Linux 6.14 and is gone from linux-enigmarsos, so
# `mkinitcpio -P` fails and the installer aborts.
drop_unresolvable_modules() {
  local conf="$1"
  [[ -f "${conf}" ]] || return 0

  local kvers=() kv line rest name kept=()
  while IFS= read -r kv; do
    kvers+=("${kv}")
  done < <(find /usr/lib/modules -mindepth 1 -maxdepth 1 -type d -printf '%f\n' 2>/dev/null || true)

  module_resolvable() {
    local m="$1"
    case "${m}" in
      crc32c-intel|crc32c_intel)
        return 1
        ;;
    esac
    [[ ${#kvers[@]} -eq 0 ]] && return 0
    local kv
    for kv in "${kvers[@]}"; do
      if command -v modinfo >/dev/null 2>&1 && modinfo -k "${kv}" "${m}" &>/dev/null; then
        return 0
      fi
    done
    return 1
  }

  line="$(grep -E '^[[:space:]]*MODULES=' "${conf}" | tail -n1 || true)"
  [[ -n "${line}" ]] || return 0
  rest="${line#*=}"
  rest="${rest#"${rest%%[![:space:]]*}"}"
  rest="${rest#\(}"
  rest="${rest%\)}"
  rest="${rest//\"/}"
  rest="${rest//\'/}"
  kept=()
  for name in ${rest}; do
    [[ -z "${name}" ]] && continue
    if module_resolvable "${name}"; then
      kept+=("${name}")
    else
      echo "    dropping unresolved mkinitcpio MODULES entry: ${name}"
    fi
  done
  sed -i -E "s|^[[:space:]]*MODULES=.*|MODULES=(${kept[*]})|" "${conf}"
}

# Strip live-only hooks if present
if [[ -f /etc/mkinitcpio.conf ]]; then
  sed -i \
    -e 's/\<archiso_pxe_nfs\>//g' \
    -e 's/\<archiso_pxe_http\>//g' \
    -e 's/\<archiso_pxe_nbd\>//g' \
    -e 's/\<archiso_pxe_common\>//g' \
    -e 's/\<archiso_loop_mnt\>//g' \
    -e 's/\<archiso\>//g' \
    -e 's/\<memdisk\>//g' \
    /etc/mkinitcpio.conf
  sed -i 's/  */ /g' /etc/mkinitcpio.conf
  # Live ISO HOOKS include encrypt/lvm2. Drop them unless the target
  # actually uses LUKS/LVM, or initramfs waits 30s for a missing device.
  if ! awk '!/^[[:space:]]*#/ && NF && $1 != "none" { found=1 } END { exit !found }' /etc/crypttab 2>/dev/null; then
    sed -i -e 's/\<sd-encrypt\>//g' -e 's/\<encrypt\>//g' /etc/mkinitcpio.conf
  fi
  if ! ls /dev/mapper/vg* /dev/mapper/*-lv* >/dev/null 2>&1 \
     && ! grep -qE '^[[:space:]]*[^#].*lvm' /etc/fstab 2>/dev/null; then
    sed -i -e 's/\<lvm2\>//g' /etc/mkinitcpio.conf
  fi
  sed -i 's/  */ /g' /etc/mkinitcpio.conf
  drop_unresolvable_modules /etc/mkinitcpio.conf
fi

if [[ ! -r /boot/vmlinuz-linux-enigmarsos && ! -r /boot/vmlinuz-linux ]]; then
  echo "ERROR: no kernel in target /boot (seed-kernel should have copied it)" >&2
  ls -la /boot || true
  exit 1
fi

echo "==> Kernels present:"
ls -l /boot/vmlinuz-* 2>/dev/null || true
echo "==> EnigmarsOS: fix-mkinitcpio done"
