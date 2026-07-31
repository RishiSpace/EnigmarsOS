#!/usr/bin/env bash
# Build EnigmaOS ISO with mkarchiso
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROFILE="${ROOT}/archiso"
OUT="${ROOT}/out"
WORK="${ROOT}/work"

if [[ ${EUID} -ne 0 ]]; then
  echo "Run as root (mkarchiso requires root)." >&2
  exit 1
fi

if ! command -v mkarchiso >/dev/null 2>&1; then
  echo "mkarchiso not found. Install archiso." >&2
  exit 1
fi

# Sync root packages list into profile if present
if [[ -f "${ROOT}/packages.x86_64" ]]; then
  cp -f "${ROOT}/packages.x86_64" "${PROFILE}/packages.x86_64"
fi
if [[ -f "${ROOT}/profiledef.sh" ]]; then
  cp -f "${ROOT}/profiledef.sh" "${PROFILE}/profiledef.sh"
fi

mkdir -p "${OUT}"
rm -rf "${WORK}"
mkdir -p "${WORK}"

export SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(date +%s)}"

mkarchiso -v -w "${WORK}" -o "${OUT}" "${PROFILE}"

echo "ISO artifacts in ${OUT}"
ls -lh "${OUT}"
