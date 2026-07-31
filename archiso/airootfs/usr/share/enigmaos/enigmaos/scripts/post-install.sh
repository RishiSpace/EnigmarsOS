#!/usr/bin/env bash
# EnigmaOS post-install (runs inside target via Calamares shellprocess)
set -euo pipefail

echo "EnigmaOS post-install starting..."

# Identity
install -Dm644 /usr/lib/os-release /etc/os-release 2>/dev/null || true

# Plymouth theme
if command -v plymouth-set-default-theme >/dev/null 2>&1; then
  plymouth-set-default-theme -R enigmaos || true
fi

# SDDM theme
mkdir -p /etc/sddm.conf.d
cat >/etc/sddm.conf.d/10-enigmaos.conf <<'SDDM'
[Theme]
Current=enigmaos
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
mkdir -p /etc/skel/.config/enigmaos
echo "show=true" > /etc/skel/.config/enigmaos/welcome.conf

# Reflector once
if command -v reflector >/dev/null 2>&1; then
  reflector --protocol https --latest 15 --sort rate --save /etc/pacman.d/mirrorlist || true
fi

# Rebuild initramfs with encryption hooks if needed
if command -v mkinitcpio >/dev/null 2>&1; then
  mkinitcpio -P || true
fi

echo "EnigmaOS post-install complete."
