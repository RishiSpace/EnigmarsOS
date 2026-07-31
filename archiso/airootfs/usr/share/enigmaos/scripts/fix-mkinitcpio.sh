#!/usr/bin/env bash
# Runs inside the TARGET root via Calamares shellprocess (chrooted).
# Rewrites live archiso presets to a normal installed-system preset.
set -euo pipefail

echo "==> EnigmaOS: fix-mkinitcpio"

rm -f /etc/mkinitcpio.conf.d/archiso.conf
rm -f /etc/mkinitcpio.d/*.preset.pacnew 2>/dev/null || true

cat >/etc/mkinitcpio.d/linux.preset <<'EOF'
# mkinitcpio preset file for the 'linux' package on EnigmaOS (installed system)

ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"

PRESETS=('default' 'fallback')

default_image="/boot/initramfs-linux.img"

fallback_image="/boot/initramfs-linux-fallback.img"
fallback_options="-S autodetect"
EOF

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

if [[ ! -r /boot/vmlinuz-linux ]]; then
  echo "ERROR: /boot/vmlinuz-linux missing in target (seed-kernel should have copied it)" >&2
  ls -la /boot || true
  exit 1
fi

echo "==> Kernel present: $(ls -l /boot/vmlinuz-linux)"
echo "==> EnigmaOS: fix-mkinitcpio done"
