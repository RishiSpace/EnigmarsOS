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
fi

if [[ ! -r /boot/vmlinuz-linux-enigmarsos && ! -r /boot/vmlinuz-linux ]]; then
  echo "ERROR: no kernel in target /boot (seed-kernel should have copied it)" >&2
  ls -la /boot || true
  exit 1
fi

echo "==> Kernels present:"
ls -l /boot/vmlinuz-* 2>/dev/null || true
echo "==> EnigmarsOS: fix-mkinitcpio done"
