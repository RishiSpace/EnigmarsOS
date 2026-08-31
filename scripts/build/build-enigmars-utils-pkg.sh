#!/usr/bin/env bash
# Clone enigmars-utils from GitHub and add the Arch package to enigmarsos-local.
# Runs inside the Arch ISO build container (makepkg + repo-add).
set -euo pipefail

REPO="${ENIGMARS_UTILS_GIT:-https://github.com/RishiSpace/enigmars-utils.git}"
DEST="${ENIGMARSOS_LOCAL_REPO:-/opt/enigmarsos-repo}"
SRC="${ENIGMARS_UTILS_SRC:-/home/builder/enigmars-utils}"
BUILD_USER="${ENIGMARS_UTILS_BUILD_USER:-builder}"

if [[ "$(id -u)" -ne 0 ]]; then
  echo "error: build-enigmars-utils-pkg.sh must run as root in the ISO container" >&2
  exit 1
fi

need() { command -v "$1" >/dev/null 2>&1 || { echo "error: missing $1" >&2; exit 1; }; }
need git
need makepkg
need repo-add

echo "==> Building enigmars-utils from ${REPO}"
rm -rf "${SRC}"
install -d -o "${BUILD_USER}" -g "${BUILD_USER}" "$(dirname "${SRC}")"
sudo -u "${BUILD_USER}" git clone --depth 1 "${REPO}" "${SRC}"
sudo -u "${BUILD_USER}" bash -lc "
  set -euo pipefail
  cd '${SRC}/packaging/arch'
  makepkg -f --noconfirm --needed -p PKGBUILD.local
"

mkdir -p "${DEST}"
shopt -s nullglob
pkgs=("${SRC}"/packaging/arch/enigmars-utils-*.pkg.tar.zst)
((${#pkgs[@]})) || { echo "error: makepkg produced no enigmars-utils package" >&2; exit 1; }
cp -v "${pkgs[@]}" "${DEST}/"

(
  cd "${DEST}"
  repo-add enigmarsos-local.db.tar.gz enigmars-utils-*.pkg.tar.zst
  for stem in enigmarsos-local.db enigmarsos-local.files; do
    if [[ -L "${stem}" ]]; then
      target="$(readlink -f "${stem}")"
      rm -f "${stem}"
      cp -a "${target}" "${stem}"
    fi
  done
)

echo "==> enigmars-utils in ${DEST}:"
ls -lh "${DEST}"/enigmars-utils-*.pkg.tar.zst
