#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
echo "EnigmaOS tree check"
test -f "${ROOT}/profiledef.sh"
test -f "${ROOT}/packages.x86_64"
test -f "${ROOT}/public/EnigmaOS.png"
test -f "${ROOT}/archiso/airootfs/etc/pacman.d/hooks/enigmaos-os-release.hook"
test -f "${ROOT}/archiso/airootfs/usr/share/libalpm/scripts/enigmaos-os-release"
test -f "${ROOT}/packages/enigmaos-welcome/enigmaos-welcome"
test -f "${ROOT}/scripts/build/docker-build-iso.sh"
test -f "${ROOT}/docker/Dockerfile"
# Identity branding must target rishispace
grep -q 'enigmaos.rishispace.dev' "${ROOT}/archiso/airootfs/usr/share/libalpm/scripts/enigmaos-os-release"
grep -q 'rishi@rishispace.dev' "${ROOT}/packages/enigmaos-filesystem/PKGBUILD" || true
echo "OK: basic structure intact"
