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
wanted = []
for a in assets:
    name = a.get("name") or ""
    if name.startswith("linux-enigmarsos") and (
        name.endswith(".pkg.tar.zst")
        or name in (
            "linux-enigmarsos.db",
            "linux-enigmarsos.db.tar.gz",
            "linux-enigmarsos.files",
            "linux-enigmarsos.files.tar.gz",
        )
    ):
        wanted.append(a)
if not any(a["name"].endswith(".pkg.tar.zst") for a in wanted):
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

shopt -s nullglob
pkgs=("${DEST}"/linux-enigmarsos-*.pkg.tar.zst)
((${#pkgs[@]})) || { echo "error: no packages in ${DEST}" >&2; exit 1; }

# Prefer the db shipped on Latest (Ubuntu CI has no pacman/repo-add).
# Fall back to repo-add on Arch hosts. Docker ISO build rebuilds the db
# if neither is available yet.
if [[ -f "${DEST}/linux-enigmarsos.db" || -f "${DEST}/linux-enigmarsos.db.tar.gz" ]]; then
  echo "==> Using linux-enigmarsos.db from GitHub Latest (no repo-add needed)"
elif command -v repo-add >/dev/null 2>&1; then
  echo "==> Building linux-enigmarsos.db with repo-add"
  (
    cd "${DEST}"
    rm -f linux-enigmarsos.db linux-enigmarsos.db.tar.gz \
          linux-enigmarsos.files linux-enigmarsos.files.tar.gz \
          linux-enigmarsos.db.tar.gz.old linux-enigmarsos.files.tar.gz.old
    repo-add --new --remove linux-enigmarsos.db.tar.gz linux-enigmarsos-*.pkg.tar.zst
    for stem in linux-enigmarsos.db linux-enigmarsos.files; do
      if [[ -L "${stem}" ]]; then
        target="$(readlink -f "${stem}")"
        rm -f "${stem}"
        cp -a "${target}" "${stem}"
      fi
    done
  )
else
  echo "==> repo-add not on this host; Docker ISO step will generate the db"
fi

echo "==> Kernel repo ready:"
ls -lh "${DEST}"
echo "    pacman Server = file:///build/repo/x86_64   (Docker ISO build)"
