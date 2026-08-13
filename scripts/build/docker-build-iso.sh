#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
IMAGE_NAME="${ENIGMARSOS_DOCKER_IMAGE:-enigmarsos-iso-builder:latest}"
OUT_DIR="${ROOT}/out"
WORK_DIR="${ROOT}/work"

cd "${ROOT}"

if ! command -v docker >/dev/null 2>&1; then
  echo "error: docker is not installed or not in PATH" >&2
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  echo "error: cannot talk to the Docker daemon (permissions?)" >&2
  exit 1
fi

echo "==> Preparing archiso profile"
bash "${ROOT}/scripts/build/prepare-profile.sh"

if [[ "${ENIGMARSOS_SKIP_IMAGE_BUILD:-0}" != "1" ]]; then
  echo "==> Building Docker image ${IMAGE_NAME}"
  docker build -t "${IMAGE_NAME}" "${ROOT}/docker"
else
  echo "==> Skipping image rebuild (ENIGMARSOS_SKIP_IMAGE_BUILD=1)"
fi

mkdir -p "${OUT_DIR}"
# work dir may be root-owned from prior runs — clear inside container
docker run --rm --privileged -v "${ROOT}:/build" -w /build --entrypoint bash "${IMAGE_NAME}" \
  -c 'rm -rf /build/work && mkdir -p /build/work /build/out'

DOCKER_ARGS=(
  --rm
  --privileged
  --security-opt apparmor=unconfined
  -e SOURCE_DATE_EPOCH="${SOURCE_DATE_EPOCH:-$(date +%s)}"
  -e ENIGMARSOS_ROOT=/build
  -v "${ROOT}:/build"
  -v enigmarsos-pkgcache:/var/cache/pacman/pkg
  -w /build
  --tmpfs /tmp:rw,exec,nosuid,size=8g
)

echo "==> Running mkarchiso in container"
echo "    This downloads a full desktop package set; first build can take a long time."
docker run "${DOCKER_ARGS[@]}" "${IMAGE_NAME}"

# mkarchiso runs as root inside the container; reclaim host ownership so
# follow-up steps (checksums, uploads) can write into out/.
HOST_UID="$(id -u)"
HOST_GID="$(id -g)"
echo "==> Fixing ownership of out/ and work/ (${HOST_UID}:${HOST_GID})"
docker run --rm --privileged \
  -v "${ROOT}:/build" \
  -w /build \
  --entrypoint bash \
  "${IMAGE_NAME}" \
  -c "chown -R ${HOST_UID}:${HOST_GID} /build/out /build/work 2>/dev/null || true"
# Fallback when host can sudo (GitHub Actions runners)
if command -v sudo >/dev/null 2>&1; then
  sudo chown -R "${HOST_UID}:${HOST_GID}" "${OUT_DIR}" "${WORK_DIR}" 2>/dev/null || true
fi

echo "==> Host artifacts:"
ls -lh "${OUT_DIR}" || true
