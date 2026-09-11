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

load_igpu_kms() {
  local v
  while IFS= read -r v; do
    case "${v}" in
      0x8086)
        modprobe i915 2>/dev/null || true
        modprobe xe 2>/dev/null || true
        ;;
      0x1002)
        modprobe amdgpu 2>/dev/null || true
        ;;
    esac
  done
  if command -v udevadm >/dev/null 2>&1; then
    udevadm settle -t 8 >/dev/null 2>&1 || true
  fi
}

# Laptop panel on Intel/AMD. A desktop Intel iGPU with no cable is ignored.
igpu_has_connected_output() {
  local conn card vendor st
  shopt -s nullglob
  for conn in /sys/class/drm/card*-*; do
    [[ -f "${conn}/status" ]] || continue
    st="$(cat "${conn}/status" 2>/dev/null || true)"
    [[ "${st}" == "connected" ]] || continue
    card="/sys/class/drm/$(basename "${conn}" | sed 's/-.*//')"
    vendor="$(cat "${card}/device/vendor" 2>/dev/null || true)"
    case "${vendor}" in
      0x8086|0x1002) return 0 ;;
    esac
  done
  return 1
}

load_nvidia() {
  local with_fbdev="${1:-0}"
  local kver
  kver="$(uname -r)"
  if ! modinfo nvidia >/dev/null 2>&1; then
    echo "    ERROR: nvidia.ko not found for kernel ${kver}" >&2
    return 1
  fi
  if ! modprobe nvidia; then
    echo "    ERROR: modprobe nvidia failed (Secure Boot unsigned module?)" >&2
    return 1
  fi
  modprobe nvidia_modeset 2>/dev/null || true
  modprobe nvidia_uvm 2>/dev/null || true
  if ((with_fbdev)); then
    modprobe nvidia_drm modeset=1 fbdev=1 || return 1
  else
    modprobe nvidia_drm modeset=1 || return 1
  fi
  return 0
}

ids="$(nvidia_devids || true)"
vga_vendors="$(pci_vga_vendors || true)"

write_nvidia_conf() {
  local offload="${1:-0}"
  mkdir -p /etc/modprobe.d /etc/mkinitcpio.conf.d /etc/enigmarsos/cmdline.d
  rm -f /etc/modprobe.d/enigmarsos-gpu.conf
  if ((offload)); then
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
# NVIDIA owns the display (no connected Intel/AMD panel)
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
  echo "    kernel $(uname -r)"
  echo "${vga_vendors}" | load_igpu_kms
  fbdev=1
  if igpu_has_connected_output; then
    fbdev=0
    echo "    connected Intel/AMD panel → load NVIDIA without fbdev"
  else
    echo "    NVIDIA is the display GPU"
  fi
  if ! echo "${ids}" | turing_or_newer; then
    echo "    pre-Turing: live ISO ships nvidia-open only"
    exit 0
  fi
  if load_nvidia "${fbdev}"; then
    echo "    nvidia modules loaded (nvidia-smi should work)"
  else
    echo "    NVIDIA failed to load; trying nouveau so the session is not stuck at 1024x768" >&2
    modprobe nouveau 2>/dev/null || true
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
echo "${vga_vendors}" | load_igpu_kms
offload=0
if igpu_has_connected_output; then
  offload=1
fi

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
write_nvidia_conf "${offload}"
if ((offload)); then
  echo "==> EnigmarsOS: NVIDIA kept for offload; iGPU remains the display GPU"
else
  echo "==> EnigmarsOS: NVIDIA drivers configured as the display GPU"
fi
exit 0
