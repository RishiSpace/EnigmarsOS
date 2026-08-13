#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
AIO="${ROOT}/archiso/airootfs"

echo "==> Syncing EnigmarsOS branding into airootfs"

install -Dm644 "${ROOT}/public/EnigmarsOS.png" "${AIO}/usr/share/enigmarsos/logos/EnigmarsOS.png"
install -Dm644 "${ROOT}/public/EnigmarsOS.png" "${AIO}/usr/share/pixmaps/enigmarsos.png"
if [[ -f "${ROOT}/public/EnigmarsOS.svg" ]]; then
  install -Dm644 "${ROOT}/public/EnigmarsOS.svg" "${AIO}/usr/share/enigmarsos/logos/EnigmarsOS.svg"
fi
if [[ -f "${ROOT}/wallpapers/enigmarsos-amoled.png" ]]; then
  install -Dm644 "${ROOT}/wallpapers/enigmarsos-amoled.png" \
    "${AIO}/usr/share/enigmarsos/wallpapers/enigmarsos-amoled.png"
fi

# Kickoff / Application Launcher logo: thin icon theme overriding start-here-kde
# (inherits Papirus-Dark). Also seed hicolor so Icon=enigmarsos desktop files work.
if [[ -d "${ROOT}/themes/icons/EnigmarsOS" ]]; then
  rm -rf "${AIO}/usr/share/icons/EnigmarsOS"
  mkdir -p "${AIO}/usr/share/icons"
  cp -a "${ROOT}/themes/icons/EnigmarsOS" "${AIO}/usr/share/icons/EnigmarsOS"
  # hicolor brand + start-menu fallbacks (used when theme search falls through)
  for size in 16 22 24 32 48; do
    src="${ROOT}/themes/icons/EnigmarsOS/${size}x${size}/apps/enigmarsos.png"
    if [[ -f "${src}" ]]; then
      install -Dm644 "${src}" \
        "${AIO}/usr/share/icons/hicolor/${size}x${size}/apps/enigmarsos.png"
      install -Dm644 "${src}" \
        "${AIO}/usr/share/icons/hicolor/${size}x${size}/apps/start-here-kde.png"
      install -Dm644 "${src}" \
        "${AIO}/usr/share/icons/hicolor/${size}x${size}/places/start-here-kde.png"
    fi
  done
  if [[ -f "${ROOT}/public/EnigmarsOS.svg" ]]; then
    install -Dm644 "${ROOT}/public/EnigmarsOS.svg" \
      "${AIO}/usr/share/icons/hicolor/scalable/apps/enigmarsos.svg"
    install -Dm644 "${ROOT}/public/EnigmarsOS.svg" \
      "${AIO}/usr/share/icons/hicolor/scalable/apps/start-here-kde.svg"
    install -Dm644 "${ROOT}/public/EnigmarsOS.svg" \
      "${AIO}/usr/share/icons/hicolor/scalable/places/start-here-kde.svg"
  fi
fi

# Look-and-feel package (keeps airootfs in sync with themes/)
if [[ -d "${ROOT}/themes/plasma/org.enigmarsos.desktop" ]]; then
  rm -rf "${AIO}/usr/share/plasma/look-and-feel/org.enigmarsos.desktop"
  mkdir -p "${AIO}/usr/share/plasma/look-and-feel"
  cp -a "${ROOT}/themes/plasma/org.enigmarsos.desktop" \
    "${AIO}/usr/share/plasma/look-and-feel/org.enigmarsos.desktop"
fi

if [[ -d "${ROOT}/calamares" ]]; then
  mkdir -p "${AIO}/etc/calamares"
  cp -a "${ROOT}/calamares/settings.conf" "${AIO}/etc/calamares/" 2>/dev/null || true
  cp -a "${ROOT}/calamares/modules" "${AIO}/etc/calamares/" 2>/dev/null || true
  cp -a "${ROOT}/calamares/branding" "${AIO}/etc/calamares/" 2>/dev/null || true
fi

# Custom SDDM theme is not shipped; greeter uses stock Breeze (see etc/sddm.conf*).
rm -rf "${AIO}/usr/share/sddm/themes/enigmarsos"

if [[ -d "${ROOT}/plymouth/enigmarsos" ]]; then
  mkdir -p "${AIO}/usr/share/plymouth/themes"
  cp -a "${ROOT}/plymouth/enigmarsos" "${AIO}/usr/share/plymouth/themes/"
fi

if [[ -f "${ROOT}/packages/enigmarsos-welcome/enigmarsos-welcome" ]]; then
  install -Dm755 "${ROOT}/packages/enigmarsos-welcome/enigmarsos-welcome" \
    "${AIO}/usr/local/bin/enigmarsos-welcome"
  install -Dm644 "${ROOT}/packages/enigmarsos-welcome/enigmarsos-welcome.desktop" \
    "${AIO}/usr/share/applications/enigmarsos-welcome.desktop"
fi

# Keep package list + identity in sync
cp -f "${ROOT}/packages.x86_64" "${ROOT}/archiso/packages.x86_64"
cp -f "${ROOT}/profiledef.sh" "${ROOT}/archiso/profiledef.sh"
chmod +x "${ROOT}/archiso/profiledef.sh"

# Identity applied via pacman hook enigmarsos-os-release (avoids filesystem package conflict)

echo "==> Profile prepared"

# Avoid package file conflicts (airootfs is copied before pacstrap)
rm -f "${AIO}/usr/share/wayland-sessions/plasma.desktop"
rm -f "${AIO}/usr/share/xsessions/plasmax11.desktop"
rm -f "${AIO}/etc/security/limits.d/10-gamemode.conf"
# Keep /etc/os-release + usr/lib/os-release; pacman NoExtract protects them
rm -f "${AIO}/etc/os-release" "${AIO}/usr/lib/os-release"
