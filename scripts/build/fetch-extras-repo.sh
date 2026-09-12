#!/usr/bin/env bash
# Populate repo-extras/x86_64 with enigmars-extras packages + a pacman db
# so mkarchiso can pacstrap from file:///build/repo-extras/x86_64.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="${ENIGMARSOS_EXTRAS_REPO:-${ROOT}/repo-extras/x86_64}"
API="${ENIGMARS_EXTRAS_RELEASE_API:-https://api.github.com/repos/RishiSpace/enigmars-extras/releases/latest}"

mkdir -p "${DEST}"

echo "==> Fetching enigmars-extras packages into ${DEST}"

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

print(f"    release: {rel.get('tag_name')}", flush=True)
assets = rel.get("assets") or []
db_names = {
    "enigmars-extras.db",
    "enigmars-extras.db.tar.gz",
    "enigmars-extras.files",
    "enigmars-extras.files.tar.gz",
}
wanted = []
for a in assets:
    name = a.get("name") or ""
    if name.endswith(".pkg.tar.zst") and "-debug-" not in name:
        wanted.append(a)
    elif name in db_names:
        wanted.append(a)
if not any(a["name"].endswith(".pkg.tar.zst") for a in wanted):
    sys.exit("no enigmars-extras *.pkg.tar.zst assets on Latest release")

for a in wanted:
    name, url, size = a["name"], a["browser_download_url"], int(a.get("size") or 0)
    out = os.path.join(dest, name)
    if os.path.isfile(out) and size and os.path.getsize(out) == size:
        print(f"    cached {name}", flush=True)
        continue
    print(f"    downloading {name} ({size} bytes)", flush=True)
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
    print(f"    wrote {out}", flush=True)
PY

shopt -s nullglob
pkgs=("${DEST}"/*.pkg.tar.zst)
shopt -u nullglob
((${#pkgs[@]})) || { echo "error: no packages in ${DEST}" >&2; exit 1; }

if [[ -f "${DEST}/enigmars-extras.db" || -f "${DEST}/enigmars-extras.db.tar.gz" ]]; then
  echo "==> Using enigmars-extras.db from GitHub Latest (no repo-add needed)"
elif command -v repo-add >/dev/null 2>&1; then
  echo "==> Building enigmars-extras.db with repo-add"
  (
    cd "${DEST}"
    rm -f enigmars-extras.db enigmars-extras.db.tar.gz \
          enigmars-extras.files enigmars-extras.files.tar.gz \
          enigmars-extras.db.tar.gz.old enigmars-extras.files.tar.gz.old
    repo-add --new --remove enigmars-extras.db.tar.gz *.pkg.tar.zst
    for stem in enigmars-extras.db enigmars-extras.files; do
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

echo "==> extras repo ready:"
ls -lh "${DEST}"
echo "    pacman Server = file:///build/repo-extras/x86_64   (Docker ISO build)"
