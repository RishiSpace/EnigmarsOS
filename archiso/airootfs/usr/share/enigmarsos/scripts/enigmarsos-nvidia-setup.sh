#!/usr/bin/env bash
# If an NVIDIA GPU is present, install matching drivers on the *installed*
# system. Does not change the live ISO package set. Never abort the installer.
set -uo pipefail

echo "==> EnigmarsOS: NVIDIA GPU check"

nvidia_devids() {
  local d vendor class devid
  shopt -s nullglob
  for d in /sys/bus/pci/devices/*; do
    [[ -r "${d}/vendor" && -r "${d}/class" && -r "${d}/device" ]] || continue
    vendor="$(cat "${d}/vendor" 2>/dev/null || true)"
    [[ "${vendor}" == "0x10de" ]] || continue
    class="$(cat "${d}/class" 2>/dev/null || true)"
    case "${class}" in
      0x030000|0x030200) ;;
      *) continue ;;
    esac
    devid="$(cat "${d}/device" 2>/dev/null || true)"
    devid="${devid#0x}"
    [[ -n "${devid}" ]] && printf '%s\n' "${devid}"
  done
}

ids="$(nvidia_devids || true)"
if [[ -z "${ids}" ]]; then
  echo "    no NVIDIA VGA/3D GPU; skipping nvidia drivers"
  exit 0
fi

echo "    NVIDIA GPU device id(s): ${ids//$'\n'/ }"

# nvidia-open supports Turing and newer (PCI IDs 0x1e00+). Older cards need nvidia.
use_open=1
while IFS= read -r id; do
  [[ -n "${id}" ]] || continue
  if ! printf '%d' "0x${id}" >/dev/null 2>&1; then
    continue
  fi
  if (( 16#${id} < 16#1e00 )); then
    use_open=0
  fi
done <<< "${ids}"

pkgs=(nvidia-utils nvidia-settings lib32-nvidia-utils)
if ((use_open)); then
  pkgs+=(nvidia-open-dkms)
  echo "    Turing+ → nvidia-open-dkms"
else
  pkgs+=(nvidia-dkms)
  echo "    pre-Turing → nvidia-dkms"
fi

if ! command -v pacman >/dev/null 2>&1; then
  echo "WARNING: pacman missing; cannot install NVIDIA drivers" >&2
  exit 0
fi

if ! pacman -Sy --noconfirm --needed "${pkgs[@]}"; then
  echo "WARNING: NVIDIA driver install failed (network?). Continuing without it." >&2
  exit 0
fi

mkdir -p /etc/modprobe.d /etc/mkinitcpio.conf.d /etc/enigmarsos/cmdline.d
cat >/etc/modprobe.d/nvidia.conf <<'EOF'
blacklist nouveau
options nvidia-drm modeset=1 fbdev=1
EOF
cat >/etc/mkinitcpio.conf.d/nvidia.conf <<'EOF'
# Added because an NVIDIA GPU was detected at install
MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF
echo 'nvidia-drm.modeset=1 nvidia-drm.fbdev=1' >/etc/enigmarsos/cmdline.d/nvidia.conf

echo "==> EnigmarsOS: NVIDIA drivers installed"
exit 0
