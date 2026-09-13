#!/usr/bin/env bash
# Populate repo-lts/x86_64 with linux-enigmarsos-lts packages + db
# from the dedicated GitHub Release tag `lts` (not rolling Latest).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="${ENIGMARSOS_LTS_REPO:-${ROOT}/repo-lts/x86_64}"
API="${LINUX_ENIGMARSOS_LTS_RELEASE_API:-https://api.github.com/repos/RishiSpace/linux-enigmarsos/releases/tags/lts}"

mkdir -p "${DEST}"

echo "==> Fetching linux-enigmarsos-lts packages into ${DEST}"

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
    "linux-enigmarsos-lts.db",
    "linux-enigmarsos-lts.db.tar.gz",
    "linux-enigmarsos-lts.files",
    "linux-enigmarsos-lts.files.tar.gz",
}
wanted = []
for a in assets:
    name = a.get("name") or ""
    if name.startswith("linux-enigmarsos-lts") and (
        name.endswith(".pkg.tar.zst") or name in db_names
    ):
        wanted.append(a)
if not any(a["name"].endswith(".pkg.tar.zst") for a in wanted):
    sys.exit("no linux-enigmarsos-lts *.pkg.tar.zst assets on the `lts` release")

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
pkgs=("${DEST}"/linux-enigmarsos-lts-*.pkg.tar.zst)
shopt -u nullglob
((${#pkgs[@]})) || { echo "error: no LTS packages in ${DEST}" >&2; exit 1; }

if [[ -f "${DEST}/linux-enigmarsos-lts.db" || -f "${DEST}/linux-enigmarsos-lts.db.tar.gz" ]]; then
  echo "==> Using linux-enigmarsos-lts.db from GitHub (no repo-add needed)"
elif command -v repo-add >/dev/null 2>&1; then
  echo "==> Building linux-enigmarsos-lts.db with repo-add"
  (
    cd "${DEST}"
    rm -f linux-enigmarsos-lts.db linux-enigmarsos-lts.db.tar.gz \
          linux-enigmarsos-lts.files linux-enigmarsos-lts.files.tar.gz \
          linux-enigmarsos-lts.db.tar.gz.old linux-enigmarsos-lts.files.tar.gz.old
    repo-add --new --remove linux-enigmarsos-lts.db.tar.gz linux-enigmarsos-lts-*.pkg.tar.zst
    for stem in linux-enigmarsos-lts.db linux-enigmarsos-lts.files; do
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

echo "==> LTS repo ready:"
ls -lh "${DEST}"
echo "    pacman Server = file:///build/repo-lts/x86_64   (Docker ISO build)"
