#!/usr/bin/env bash
# EnigmarsOS post-install (runs inside target via Calamares shellprocess)
set -euo pipefail

echo "EnigmarsOS post-install starting..."

# Identity (hook may already have applied this)
if [[ -x /usr/local/bin/enigmarsos-branding ]]; then
  /usr/local/bin/enigmarsos-branding || true
elif [[ -f /usr/lib/os-release ]]; then
  # /etc/os-release is often a symlink — replace carefully
  rm -f /etc/os-release
  cp -f /usr/lib/os-release /etc/os-release || true
fi

# Ensure installed-system mkinitcpio preset (idempotent)
if [[ -r /boot/vmlinuz-linux ]]; then
  cat >/etc/mkinitcpio.d/linux.preset <<'EOF'
ALL_config="/etc/mkinitcpio.conf"
ALL_kver="/boot/vmlinuz-linux"
PRESETS=('default' 'fallback')
default_image="/boot/initramfs-linux.img"
fallback_image="/boot/initramfs-linux-fallback.img"
fallback_options="-S autodetect"
EOF
  rm -f /etc/mkinitcpio.conf.d/archiso.conf
  mkinitcpio -P || true
fi

# Plymouth theme
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  plymouth-set-default-theme -R enigmarsos || true
fi

# SDDM: stock Breeze greeter (custom enigmarsos theme intentionally unused)
mkdir -p /etc/sddm.conf.d
cat >/etc/sddm.conf.d/10-enigmarsos.conf <<'SDDM'
[Theme]
Current=breeze
CursorTheme=breeze_cursors
[General]
DisplayServer=wayland
SDDM

# UFW
if command -v ufw >/dev/null 2>&1; then
  ufw --force reset || true
  ufw default deny incoming
  ufw default allow outgoing
  ufw --force enable || true
fi

# Flatpak Flathub
if command -v flatpak >/dev/null 2>&1; then
  flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
fi

# Remove live user if present
if id live &>/dev/null; then
  userdel -r live 2>/dev/null || true
fi
rm -f /etc/sudoers.d/99-live
rm -f /etc/polkit-1/rules.d/49-enigmarsos-live.rules

# AppArmor
systemctl enable apparmor.service 2>/dev/null || true

# First-boot flag for welcome app
mkdir -p /etc/skel/.config/enigmarsos
echo "show=true" > /etc/skel/.config/enigmarsos/welcome.conf

# Reflector once
if command -v reflector >/dev/null 2>&1; then
  reflector --protocol https --latest 15 --sort rate --save /etc/pacman.d/mirrorlist || true
fi

# Ensure ESP has the same kernel as /boot (idempotent with install-limine)
if [[ -x /usr/share/enigmarsos/scripts/sync-esp-boot.sh ]]; then
  /usr/share/enigmarsos/scripts/sync-esp-boot.sh || true
fi

echo "EnigmarsOS post-install complete."
