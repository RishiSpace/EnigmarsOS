#!/usr/bin/env bash
# Runs inside the TARGET root via Calamares shellprocess (chrooted).
# Fixes the classic "archiso preset / vmlinuz must be readable" install failure.
set -euo pipefail

echo "==> EnigmaOS: fix-mkinitcpio"

# Drop live-medium mkinitcpio configuration
rm -f /etc/mkinitcpio.conf.d/archiso.conf
rm -f /etc/mkinitcpio.d/*.preset.pacnew 2>/dev/null || true

# Standard preset used on installed Arch/EnigmaOS systems
cat >/etc/mkinitcpio.d/linux.preset <<'EOF'
# mkinitcpio preset file for the 'linux' package on EnigmaOS (installed system)

ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"

PRESETS=('default' 'fallback')

default_image="/boot/initramfs-linux.img"

fallback_image="/boot/initramfs-linux-fallback.img"
fallback_options="-S autodetect"
EOF

# Ensure base mkinitcpio.conf exists with sensible installed hooks if missing
if [[ ! -f /etc/mkinitcpio.conf ]]; then
  cat >/etc/mkinitcpio.conf <<'EOF'
MODULES=()
BINARIES=()
FILES=()
HOOKS=(base udev autodetect microcode modconf kms keyboard keymap consolefont block filesystems fsck)
COMPRESSION="zstd"
EOF
fi

# Remove archiso-only hooks if they leaked into mkinitcpio.conf
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
  # Collapse accidental double spaces in HOOKS line
  sed -i 's/  */ /g' /etc/mkinitcpio.conf
fi

# Kernel must exist before mkinitcpio. Prefer already-installed package files;
# if missing (common after archiso unpack), reinstall from the live network/repos.
if [[ ! -r /boot/vmlinuz-linux ]]; then
  echo "==> /boot/vmlinuz-linux missing — installing linux package"
  pacman -Sy --noconfirm linux linux-headers linux-firmware amd-ucode intel-ucode mkinitcpio || \
    pacman -S --noconfirm linux linux-headers mkinitcpio
fi

if [[ ! -r /boot/vmlinuz-linux ]]; then
  echo "ERROR: /boot/vmlinuz-linux still missing after package install" >&2
  ls -la /boot || true
  exit 1
fi

echo "==> Kernel present: $(ls -l /boot/vmlinuz-linux)"
echo "==> EnigmaOS: fix-mkinitcpio done"
