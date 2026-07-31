#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="${ROOT}/packages/enigmaos-settings/files"
rm -rf "$DEST"
mkdir -p "$DEST"

# Collect skel + system defaults from airootfs
cp -a "${ROOT}/archiso/airootfs/etc/skel" "$DEST/skel"
mkdir -p "$DEST/etc"
cp -a "${ROOT}/archiso/airootfs/etc/sysctl.d" "$DEST/etc/" 2>/dev/null || true
cp -a "${ROOT}/archiso/airootfs/etc/NetworkManager" "$DEST/etc/" 2>/dev/null || true
cp -a "${ROOT}/archiso/airootfs/etc/ufw" "$DEST/etc/" 2>/dev/null || true
echo "Settings files staged in $DEST"
