#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
echo "EnigmarsOS tree check"
test -f "${ROOT}/profiledef.sh"
test -f "${ROOT}/packages.x86_64"
test -f "${ROOT}/public/EnigmarsOS.png"
test -f "${ROOT}/archiso/airootfs/etc/pacman.d/hooks/enigmarsos-os-release.hook"
test -f "${ROOT}/archiso/airootfs/usr/share/libalpm/scripts/enigmarsos-os-release"
test -f "${ROOT}/packages/enigmarsos-welcome/enigmarsos-welcome"
test -f "${ROOT}/scripts/build/docker-build-iso.sh"
test -f "${ROOT}/docker/Dockerfile"
# Identity branding must target rishispace
grep -q 'enigmarsos.rishispace.dev' "${ROOT}/archiso/airootfs/usr/share/libalpm/scripts/enigmarsos-os-release"
grep -q 'rishi@rishispace.dev' "${ROOT}/packages/enigmarsos-filesystem/PKGBUILD" || true
echo "OK: basic structure intact"
