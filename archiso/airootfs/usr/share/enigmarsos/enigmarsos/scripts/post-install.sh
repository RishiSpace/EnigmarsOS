#!/usr/bin/env bash
# EnigmarsOS post-install (runs inside target via Calamares shellprocess)
set -euo pipefail

echo "EnigmarsOS post-install starting..."

# Identity
install -Dm644 /usr/lib/os-release /etc/os-release 2>/dev/null || true

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

# AppArmor
systemctl enable apparmor.service 2>/dev/null || true

# First-boot flag for welcome app
mkdir -p /etc/skel/.config/enigmarsos
echo "show=true" > /etc/skel/.config/enigmarsos/welcome.conf

# Reflector once
if command -v reflector >/dev/null 2>&1; then
  reflector --protocol https --latest 15 --sort rate --save /etc/pacman.d/mirrorlist || true
fi

# Rebuild initramfs with encryption hooks if needed
if command -v mkinitcpio >/dev/null 2>&1; then
  mkinitcpio -P || true
fi

echo "EnigmarsOS post-install complete."
