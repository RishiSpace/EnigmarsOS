#!/usr/bin/env bash
# Runs inside the EnigmarsOS Arch build container.
set -euo pipefail

ROOT="${ENIGMARSOS_ROOT:-/build}"
PROFILE="${ENIGMARSOS_PROFILE:-${ROOT}/archiso}"
OUT="${ENIGMARSOS_OUT:-${ROOT}/out}"
WORK="${ENIGMARSOS_WORK:-${ROOT}/work}"

cd "${ROOT}"

echo "==> EnigmarsOS ISO build (container)"
echo "    root:    ${ROOT}"
echo "    profile: ${PROFILE}"
echo "    work:    ${WORK}"
echo "    out:     ${OUT}"

if [[ ! -f "${PROFILE}/profiledef.sh" ]]; then
  echo "error: missing ${PROFILE}/profiledef.sh — mount the repo at /build" >&2
  exit 1
fi

if [[ ! -f "${PROFILE}/packages.x86_64" ]]; then
  echo "error: missing packages list in profile" >&2
  exit 1
fi

# Ensure multilib on the container host
if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
  printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >>/etc/pacman.conf
fi

# Ensure local AUR repo (calamares) is available to pacstrap via profile pacman.conf
if [[ -d /opt/enigmarsos-repo ]] && [[ -f /opt/enigmarsos-repo/enigmarsos-local.db || -f /opt/enigmarsos-repo/enigmarsos-local.db.tar.gz ]]; then
  if ! grep -q '^\[enigmarsos-local\]' "${PROFILE}/pacman.conf"; then
    cat >>"${PROFILE}/pacman.conf" <<'EOF'

# Calamares and other AUR packages prebuilt into the build image
[enigmarsos-local]
SigLevel = Optional TrustAll
Server = file:///opt/enigmarsos-repo
EOF
  fi
  if ! grep -q '^\[enigmarsos-local\]' /etc/pacman.conf; then
    cat >>/etc/pacman.conf <<'EOF'

[enigmarsos-local]
SigLevel = Optional TrustAll
Server = file:///opt/enigmarsos-repo
EOF
  fi
fi

# Multilib in profile
if ! grep -q '^\[multilib\]' "${PROFILE}/pacman.conf"; then
  cat >>"${PROFILE}/pacman.conf" <<'EOF'

[multilib]
Include = /etc/pacman.d/mirrorlist
EOF
fi

if [[ -x "${ROOT}/scripts/build/prepare-profile.sh" ]]; then
  bash "${ROOT}/scripts/build/prepare-profile.sh"
fi

# enigmars-utils from GitHub → enigmarsos-local (ISO fallback if extras
# is missing that package). extras is preferred when both list it.
if [[ -x "${ROOT}/scripts/build/build-enigmars-utils-pkg.sh" ]]; then
  bash "${ROOT}/scripts/build/build-enigmars-utils-pkg.sh"
fi

# extras snapshot from prepare-profile → container pacman (pacman -Si checks)
if [[ -d /build/repo-extras/x86_64 ]] && [[ -f /build/repo-extras/x86_64/enigmars-extras.db || -f /build/repo-extras/x86_64/enigmars-extras.db.tar.gz ]]; then
  if ! grep -q '^\[enigmars-extras\]' /etc/pacman.conf; then
    cat >>/etc/pacman.conf <<'EOF'

[enigmars-extras]
SigLevel = Optional TrustAll
Server = file:///build/repo-extras/x86_64
Server = https://github.com/RishiSpace/enigmars-extras/releases/latest/download
EOF
  fi
fi

# Keep branding files from being overwritten by package extraction
if ! grep -q '^NoExtract' "${PROFILE}/pacman.conf"; then
  sed -i '/^#NoExtract/a NoExtract = usr/lib/os-release etc/os-release etc/hostname etc/motd' "${PROFILE}/pacman.conf" ||     echo 'NoExtract = usr/lib/os-release etc/os-release etc/hostname etc/motd' >> "${PROFILE}/pacman.conf"
fi

# Drop known conflicting custom files (packages own these paths)
rm -f "${PROFILE}/airootfs/usr/share/wayland-sessions/plasma.desktop"
rm -f "${PROFILE}/airootfs/usr/share/xsessions/plasmax11.desktop"
rm -f "${PROFILE}/airootfs/etc/security/limits.d/10-gamemode.conf"
# enigmars-utils ships these; airootfs copies them first and pacstrap then fails
rm -f "${PROFILE}/airootfs/usr/share/icons/hicolor/scalable/apps/enigmarsos.svg"
rm -f "${PROFILE}/airootfs/usr/share/pixmaps/enigmarsos.png"


# Re-apply local repo after prepare-profile (it may overwrite pacman.conf)
if [[ -d /opt/enigmarsos-repo ]] && ! grep -q '^\[enigmarsos-local\]' "${PROFILE}/pacman.conf"; then
  cat >>"${PROFILE}/pacman.conf" <<'EOF'

[enigmarsos-local]
SigLevel = Optional TrustAll
Server = file:///opt/enigmarsos-repo
EOF
fi

pacman -Sy --noconfirm

# Quick validation of packages that historically broke the build
for p in calamares enigmars-utils steam mesa 7zip iptables; do
  if ! pacman -Si "$p" >/dev/null 2>&1; then
    echo "error: package not resolvable: $p" >&2
    exit 1
  fi
done

mkdir -p "${OUT}"
rm -rf "${WORK}"
mkdir -p "${WORK}"

export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(date +%s)}"


# os-release is shipped in airootfs (NoExtract). Do not delete it: DKMS
# needs /etc/os-release while pacstrap installs nvidia-open-dkms.

echo "==> mkarchiso"
mkarchiso -v -w "${WORK}" -o "${OUT}" "${PROFILE}"

# Pacman ignores AbortOnFail on PostTransaction hooks, so a missing
# nvidia.ko still produces an ISO. Fail the job instead of uploading it.
iso_has_enigmarsos_nvidia() {
  local root="${WORK}/x86_64/airootfs"
  local sfs="${WORK}/iso/arch/x86_64/airootfs.sfs"
  if [[ -d "${root}/usr/lib/modules" ]] && \
     find "${root}/usr/lib/modules" -path '*enigmarsos-lts*' \( -name 'nvidia.ko' -o -name 'nvidia.ko.*' \) 2>/dev/null | grep -q .; then
    return 0
  fi
  if [[ -f "${sfs}" ]] && command -v unsquashfs >/dev/null 2>&1 && \
     unsquashfs -l "${sfs}" 2>/dev/null | grep -E 'enigmarsos-lts.*/nvidia\.ko' | grep -q .; then
    return 0
  fi
  return 1
}

echo "==> Verifying nvidia.ko for linux-enigmarsos-lts (live default kernel)"
if ! iso_has_enigmarsos_nvidia; then
  echo "ERROR: ISO is missing nvidia.ko for linux-enigmarsos-lts." >&2
  echo "       nvidia-open-dkms failed to build against that kernel." >&2
  echo "       Not publishing this image." >&2
  rm -f "${OUT}"/*.iso "${OUT}"/SHA256SUMS
  exit 1
fi
echo "==> nvidia.ko present for linux-enigmarsos-lts"

echo "==> checksums"
(
  cd "${OUT}"
  shopt -s nullglob
  isos=(*.iso)
  if ((${#isos[@]})); then
    sha256sum "${isos[@]}" | tee SHA256SUMS
    ls -lh "${isos[@]}"
  else
    echo "warning: no ISO produced in ${OUT}" >&2
    ls -la "${OUT}" || true
    exit 1
  fi
)

echo "==> EnigmarsOS ISO build complete"
