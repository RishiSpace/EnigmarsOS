#!/usr/bin/env bash
# Populate repo/x86_64 with linux-enigmarsos packages + a pacman db so
# mkarchiso can pacstrap from file:///build/repo/x86_64.
#
# GitHub Releases are the $0 mirror. Latest may not yet have a .db asset,
# so this downloads the .pkg.tar.zst files and always runs repo-add locally.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="${ENIGMARSOS_KERNEL_REPO:-${ROOT}/repo/x86_64}"
API="${LINUX_ENIGMARSOS_RELEASE_API:-https://api.github.com/repos/RishiSpace/linux-enigmarsos/releases/latest}"

mkdir -p "${DEST}"

echo "==> Fetching linux-enigmarsos packages into ${DEST}"

python3 - "${API}" "${DEST}" <<'PY'
import json, os, ssl, sys, urllib.request

api, dest = sys.argv[1], sys.argv[2]
ctx = ssl.create_default_context()
req = urllib.request.Request(api, headers={"Accept": "application/vnd.github+json", "User-Agent": "enigmarsos-iso"})
token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")
if token:
    req.add_header("Authorization", f"Bearer {token}")
with urllib.request.urlopen(req, context=ctx, timeout=60) as resp:
    rel = json.load(resp)

print(f"    release: {rel.get('tag_name')}")
assets = rel.get("assets") or []
wanted = [
    a for a in assets
    if a.get("name", "").endswith(".pkg.tar.zst") and a["name"].startswith("linux-enigmarsos")
]
if not wanted:
    sys.exit("no linux-enigmarsos *.pkg.tar.zst assets on Latest release")

for a in wanted:
    name, url, size = a["name"], a["browser_download_url"], int(a.get("size") or 0)
    out = os.path.join(dest, name)
    if os.path.isfile(out) and size and os.path.getsize(out) == size:
        print(f"    cached {name}")
        continue
    print(f"    downloading {name} ({size} bytes)")
    tmp = out + ".part"
    req = urllib.request.Request(url, headers={"User-Agent": "enigmarsos-iso", "Accept": "application/octet-stream"})
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, context=ctx, timeout=600) as src, open(tmp, "wb") as dst:
        while True:
            chunk = src.read(1024 * 1024)
            if not chunk:
                break
            dst.write(chunk)
    os.replace(tmp, out)
    print(f"    wrote {out}")
PY

# Always rebuild the db locally (GitHub Latest may not ship .db yet, and
# repo-add symlinks cannot be used as GitHub assets anyway).
if ! command -v repo-add >/dev/null 2>&1; then
  echo "error: repo-add not found (install pacman)" >&2
  exit 1
fi

shopt -s nullglob
pkgs=("${DEST}"/linux-enigmarsos-*.pkg.tar.zst)
((${#pkgs[@]})) || { echo "error: no packages in ${DEST}" >&2; exit 1; }

(
  cd "${DEST}"
  rm -f linux-enigmarsos.db linux-enigmarsos.db.tar.gz \
        linux-enigmarsos.files linux-enigmarsos.files.tar.gz \
        linux-enigmarsos.db.tar.gz.old linux-enigmarsos.files.tar.gz.old
  repo-add --new --remove linux-enigmarsos.db.tar.gz linux-enigmarsos-*.pkg.tar.zst
  # Regular-file copies (harmless locally; matches the GitHub-mirror layout)
  for stem in linux-enigmarsos.db linux-enigmarsos.files; do
    if [[ -L "${stem}" ]]; then
      target="$(readlink -f "${stem}")"
      rm -f "${stem}"
      cp -a "${target}" "${stem}"
    fi
  done
)

echo "==> Kernel repo ready:"
ls -lh "${DEST}"
echo "    pacman Server = file:///build/repo/x86_64   (Docker ISO build)"
