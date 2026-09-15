#!/usr/bin/env bash
# EnigmarsOS post-install (runs inside target via Calamares shellprocess)
set -euo pipefail

echo "EnigmarsOS post-install starting..."

# Drop ISO-only NVIDIA DKMS fail-hard hook before any pacman -S on the target
rm -f /etc/enigmarsos/iso-build \
      /etc/pacman.d/hooks/zz-enigmarsos-nvidia-dkms.hook

# Rolling v3 kernel from onboard packages (offline-safe). LTS stays as fallback.
install_rolling_kernel() {
  shopt -s nullglob
  local pkgs=() p
  for p in /usr/share/enigmarsos/offline-repo/linux-enigmarsos-[0-9]*.pkg.tar.zst \
           /usr/share/enigmarsos/offline-repo/linux-enigmarsos-headers-[0-9]*.pkg.tar.zst; do
    [[ -f "${p}" ]] || continue
    pkgs+=("${p}")
  done
  shopt -u nullglob
  if ((${#pkgs[@]})); then
    echo "==> Installing linux-enigmarsos (rolling) from onboard packages"
    pacman -U --noconfirm --needed "${pkgs[@]}"
    return 0
  fi
  echo "WARNING: onboard rolling kernel packages missing; trying configured repos" >&2
  if pacman -S --noconfirm --needed linux-enigmarsos linux-enigmarsos-headers; then
    return 0
  fi
  echo "WARNING: could not install linux-enigmarsos; installed system stays on LTS" >&2
  return 1
}

# The onboard repo is a frozen ISO-day snapshot: it must never shadow
# GitHub Latest on the installed system, or kernel updates stop forever.
sed -i '/enigmarsos-offline.conf/d' /etc/pacman.conf 2>/dev/null || true
rm -f /etc/pacman.d/enigmarsos-offline.conf
if install_rolling_kernel; then
  # ~230 MB of single-use packages; drop them once they served their purpose.
  rm -rf /usr/share/enigmarsos/offline-repo
else
  echo "WARNING: keeping onboard packages for a manual retry" >&2
fi

# NVIDIA: keep ISO drivers if a GPU is present, else remove them
if [[ -x /usr/share/enigmarsos/scripts/enigmarsos-nvidia-setup.sh ]]; then
  /usr/share/enigmarsos/scripts/enigmarsos-nvidia-setup.sh install || true
fi

# Identity (hook may already have applied this)
if [[ -x /usr/local/bin/enigmarsos-branding ]]; then
  /usr/local/bin/enigmarsos-branding || true
elif [[ -f /usr/lib/os-release ]]; then
  # /etc/os-release is often a symlink — replace carefully
  rm -f /etc/os-release
  cp -f /usr/lib/os-release /etc/os-release || true
fi

# Ensure installed-system mkinitcpio presets (idempotent)
rm -f /etc/mkinitcpio.conf.d/archiso.conf
if [[ -x /usr/share/enigmarsos/scripts/fix-mkinitcpio.sh ]]; then
  /usr/share/enigmarsos/scripts/fix-mkinitcpio.sh || true
fi
if compgen -G '/boot/vmlinuz-*' > /dev/null; then
  mkinitcpio -P || true
fi
# Restage ESP *before* later optional steps. Limine still has the live
# initramfs until this runs; skipping it drops boot into
# "device did not show up after 30 seconds".
if [[ -x /usr/share/enigmarsos/scripts/sync-esp-boot.sh ]]; then
  /usr/share/enigmarsos/scripts/sync-esp-boot.sh || true
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

# Restage Limine kernels on boot/shutdown (covers Discover/PackageKit)
systemctl enable enigmarsos-sync-esp.service 2>/dev/null || true

# Pin Enigmars Utils on the Desktop and autostart it for real users (not live)
copy_if_different() {
  local src="$1" dest="$2" mode="$3"
  [[ -f "${src}" ]] || return 0
  mkdir -p "$(dirname "${dest}")"
  if [[ "$(readlink -f "${src}" 2>/dev/null || true)" == "$(readlink -f "${dest}" 2>/dev/null || true)" ]]; then
    chmod "${mode}" "${dest}" 2>/dev/null || true
    return 0
  fi
  install -m"${mode}" "${src}" "${dest}"
}
pin_enigmars_utils() {
  local home="$1" src
  [[ -d "${home}" ]] || return 0
  mkdir -p "${home}/Desktop" "${home}/.config/autostart"
  src="/usr/share/applications/org.enigmars.Util.desktop"
  [[ -f "${src}" ]] || src="/etc/skel/Desktop/org.enigmars.Util.desktop"
  copy_if_different "${src}" "${home}/Desktop/org.enigmars.Util.desktop" 755
  copy_if_different \
    /etc/skel/.config/autostart/org.enigmars.Util.desktop \
    "${home}/.config/autostart/org.enigmars.Util.desktop" 644
  rm -f "${home}/Desktop/install-enigmarsos.desktop"
  local owner
  owner="$(stat -c '%U:%G' "${home}" 2>/dev/null || true)"
  if [[ -n "${owner}" ]]; then
    chown -R "${owner}" "${home}/Desktop" "${home}/.config/autostart" 2>/dev/null || true
  fi
}
rm -f /etc/skel/Desktop/install-enigmarsos.desktop
pin_enigmars_utils /etc/skel || true
for home in /home/*; do
  [[ -d "${home}" ]] || continue
  [[ "$(basename "${home}")" == live ]] && continue
  pin_enigmars_utils "${home}" || true
done

# Reflector once
if command -v reflector >/dev/null 2>&1; then
  reflector --protocol https --latest 15 --sort rate --save /etc/pacman.d/mirrorlist || true
fi

echo "EnigmarsOS post-install complete."
