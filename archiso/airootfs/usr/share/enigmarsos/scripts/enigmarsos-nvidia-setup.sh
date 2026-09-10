#!/usr/bin/env bash
# Live ISO + installed system NVIDIA helper.
# Packages live on the ISO; this only loads or removes them.
# Never abort the installer.
set -uo pipefail

mode="${1:-install}"
echo "==> EnigmarsOS: NVIDIA GPU check (${mode})"

pci_vga_vendors() {
  local d vendor class
  shopt -s nullglob
  for d in /sys/bus/pci/devices/*; do
    [[ -r "${d}/vendor" && -r "${d}/class" ]] || continue
    class="$(cat "${d}/class" 2>/dev/null || true)"
    case "${class}" in
      0x030000|0x030200) ;;
      *) continue ;;
    esac
    vendor="$(cat "${d}/vendor" 2>/dev/null || true)"
    printf '%s\n' "${vendor}"
  done
}

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

# Intel 8086 / AMD 1002 iGPU or APU display next to NVIDIA → hybrid (PRIME).
has_igpu() {
  local v
  while IFS= read -r v; do
    case "${v}" in
      0x8086|0x1002) return 0 ;;
    esac
  done
  return 1
}

turing_or_newer() {
  local id
  while IFS= read -r id; do
    [[ -n "${id}" ]] || continue
    printf '%d' "0x${id}" >/dev/null 2>&1 || continue
    if (( 16#${id} < 16#1e00 )); then
      return 1
    fi
  done
  return 0
}

ids="$(nvidia_devids || true)"
vga_vendors="$(pci_vga_vendors || true)"
hybrid=0
if [[ -n "${ids}" ]] && echo "${vga_vendors}" | has_igpu; then
  hybrid=1
fi

write_nvidia_conf() {
  local hybrid_mode="${1:-0}"
  mkdir -p /etc/modprobe.d /etc/mkinitcpio.conf.d /etc/enigmarsos/cmdline.d
  rm -f /etc/modprobe.d/enigmarsos-gpu.conf
  if ((hybrid_mode)); then
    # iGPU keeps the panel; NVIDIA is offload-only (no early KMS / fbdev).
    cat >/etc/modprobe.d/nvidia.conf <<'EOF'
blacklist nouveau
options nvidia-drm modeset=1
EOF
    rm -f /etc/mkinitcpio.conf.d/nvidia.conf
    echo 'nvidia-drm.modeset=1' >/etc/enigmarsos/cmdline.d/nvidia.conf
  else
    cat >/etc/modprobe.d/nvidia.conf <<'EOF'
blacklist nouveau
options nvidia-drm modeset=1 fbdev=1
EOF
    cat >/etc/mkinitcpio.conf.d/nvidia.conf <<'EOF'
# NVIDIA-only machine (no Intel/AMD iGPU)
MODULES+=(nvidia nvidia_modeset nvidia_uvm nvidia_drm)
EOF
    echo 'nvidia-drm.modeset=1 nvidia-drm.fbdev=1' >/etc/enigmarsos/cmdline.d/nvidia.conf
  fi
}

if [[ "${mode}" == "live" ]]; then
  if [[ -z "${ids}" ]]; then
    echo "    no NVIDIA GPU; nvidia modules stay blacklisted"
    exit 0
  fi
  echo "    NVIDIA GPU device id(s): ${ids//$'\n'/ }"
  if ((hybrid)); then
    echo "    hybrid Intel/AMD iGPU + NVIDIA; leave iGPU as display (no early nvidia load)"
    exit 0
  fi
  if echo "${ids}" | turing_or_newer; then
    modprobe nvidia 2>/dev/null || true
    modprobe nvidia_modeset 2>/dev/null || true
    modprobe nvidia_uvm 2>/dev/null || true
    modprobe nvidia_drm modeset=1 fbdev=1 2>/dev/null || true
    echo "    loaded nvidia-open modules for live session"
  else
    echo "    pre-Turing GPU: live ISO ships nvidia-open only; using whatever KMS is available"
  fi
  exit 0
fi

# --- installed system (Calamares post-install) ---
if [[ -z "${ids}" ]]; then
  echo "    no NVIDIA GPU; removing NVIDIA packages copied from the live ISO"
  pacman -Rns --noconfirm nvidia-open-dkms nvidia-dkms nvidia-utils nvidia-settings lib32-nvidia-utils 2>/dev/null || true
  rm -f /etc/modprobe.d/nvidia.conf \
        /etc/modprobe.d/enigmarsos-gpu.conf \
        /etc/mkinitcpio.conf.d/nvidia.conf \
        /etc/enigmarsos/cmdline.d/nvidia.conf
  exit 0
fi

echo "    NVIDIA GPU device id(s): ${ids//$'\n'/ }"
pkgs=(nvidia-utils nvidia-settings lib32-nvidia-utils)
if echo "${ids}" | turing_or_newer; then
  pkgs+=(nvidia-open-dkms)
  echo "    Turing+ → nvidia-open-dkms"
else
  pkgs+=(nvidia-dkms)
  echo "    pre-Turing → nvidia-dkms (replaces nvidia-open-dkms)"
  pacman -Rdd --noconfirm nvidia-open-dkms 2>/dev/null || true
fi

if command -v pacman >/dev/null 2>&1; then
  pacman -Sy --noconfirm --needed "${pkgs[@]}" || \
    echo "WARNING: NVIDIA package sync failed; keeping ISO copies if present" >&2
fi
write_nvidia_conf "${hybrid}"
if ((hybrid)); then
  echo "==> EnigmarsOS: NVIDIA kept for offload; iGPU remains the display GPU"
else
  echo "==> EnigmarsOS: NVIDIA drivers configured for installed system"
fi
exit 0
