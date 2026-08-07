#!/usr/bin/env bash
# Force SDDM to use the stock Plasma Breeze greeter.
# (Custom EnigmarsOS SDDM theme is not used.)
#
# Usage:
#   sudo bash repair-sddm-theme.sh            # fix running system
#   sudo bash repair-sddm-theme.sh /mnt       # fix mounted install root
set -uo pipefail

ROOT="${1:-/}"
CONF_D="${ROOT%/}/etc/sddm.conf.d"
MAIN_CONF="${ROOT%/}/etc/sddm.conf"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "ERROR: run as root" >&2
  exit 1
fi

mkdir -p "${CONF_D}"
cat >"${CONF_D}/10-enigmarsos.conf" <<'EOF'
[Theme]
Current=breeze
CursorTheme=breeze_cursors
[General]
DisplayServer=wayland
EOF

if [[ -f "${MAIN_CONF}" ]]; then
  # Keep other keys; force theme to breeze if a [Theme] Current= line exists
  if grep -q '^Current=' "${MAIN_CONF}"; then
    sed -i 's/^Current=.*/Current=breeze/' "${MAIN_CONF}"
  else
    if grep -q '^\[Theme\]' "${MAIN_CONF}"; then
      sed -i '/^\[Theme\]/a Current=breeze' "${MAIN_CONF}"
    else
      printf '\n[Theme]\nCurrent=breeze\nCursorTheme=breeze_cursors\n' >>"${MAIN_CONF}"
    fi
  fi
fi

echo "SDDM theme set to breeze under ${ROOT}"
if [[ "${ROOT}" == "/" ]] && command -v systemctl >/dev/null 2>&1; then
  systemctl restart sddm 2>/dev/null || echo "Restart SDDM when ready: systemctl restart sddm"
else
  echo "Reboot the installed system (or chroot and: systemctl restart sddm)"
fi
