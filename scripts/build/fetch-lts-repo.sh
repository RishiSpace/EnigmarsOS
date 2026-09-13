#!/usr/bin/env bash
# Populate repo-lts/x86_64 with linux-enigmarsos-lts packages + db.
# Prefers a moving tag named `lts`; otherwise the newest GitHub Release
# that has linux-enigmarsos-lts-*.pkg.tar.zst (e.g. linux-enigmarsos-lts-6.18.51).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DEST="${ENIGMARSOS_LTS_REPO:-${ROOT}/repo-lts/x86_64}"
API_BASE="${LINUX_ENIGMARSOS_API:-https://api.github.com/repos/RishiSpace/linux-enigmarsos}"

mkdir -p "${DEST}"

echo "==> Fetching linux-enigmarsos-lts packages into ${DEST}"

python3 - "${API_BASE}" "${DEST}" <<'PY'
import json, os, ssl, sys, urllib.error, urllib.request

api_base, dest = sys.argv[1], sys.argv[2]
ctx = ssl.create_default_context()
token = os.environ.get("GH_TOKEN") or os.environ.get("GITHUB_TOKEN")

def get(url):
    req = urllib.request.Request(url, headers={
        "Accept": "application/vnd.github+json",
        "User-Agent": "enigmarsos-iso",
    })
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    with urllib.request.urlopen(req, context=ctx, timeout=60) as resp:
        return json.load(resp)

def lts_assets(rel):
    db_names = {
        "linux-enigmarsos-lts.db",
        "linux-enigmarsos-lts.db.tar.gz",
        "linux-enigmarsos-lts.files",
        "linux-enigmarsos-lts.files.tar.gz",
    }
    wanted = []
    for a in rel.get("assets") or []:
        name = a.get("name") or ""
        if name.startswith("linux-enigmarsos-lts") and (
            name.endswith(".pkg.tar.zst") or name in db_names
        ):
            wanted.append(a)
    return wanted

rel = None
try:
    rel = get(f"{api_base}/releases/tags/lts")
    if not any(a["name"].endswith(".pkg.tar.zst") for a in lts_assets(rel)):
        rel = None
except urllib.error.HTTPError as e:
    if e.code != 404:
        raise
    rel = None

if rel is None:
    releases = get(f"{api_base}/releases?per_page=30")
    for candidate in releases:
        if candidate.get("draft") or candidate.get("prerelease"):
            continue
        wanted = lts_assets(candidate)
        if any(a["name"].endswith(".pkg.tar.zst") for a in wanted):
            rel = candidate
            break

if rel is None:
    sys.exit("no GitHub Release with linux-enigmarsos-lts *.pkg.tar.zst (tag `lts` or linux-enigmarsos-lts-*)")

tag = rel.get("tag_name") or ""
print(f"    release: {tag}", flush=True)
wanted = lts_assets(rel)

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

with open(os.path.join(dest, ".release-tag"), "w", encoding="utf-8") as fh:
    fh.write(tag + "\n")
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

TAG_FILE="${DEST}/.release-tag"
if [[ -s "${TAG_FILE}" ]]; then
  LTS_TAG="$(tr -d '[:space:]' < "${TAG_FILE}")"
  LTS_URL="https://github.com/RishiSpace/linux-enigmarsos/releases/download/${LTS_TAG}"
  echo "==> Pinning LTS pacman Server to ${LTS_URL}"
  sed -i "s|releases/download/lts|releases/download/${LTS_TAG}|g" \
    "${ROOT}/archiso/airootfs/etc/pacman.d/linux-enigmarsos-lts.conf" \
    "${ROOT}/archiso/pacman.conf"
fi

echo "==> LTS repo ready:"
ls -lh "${DEST}"
echo "    pacman Server = file:///build/repo-lts/x86_64   (Docker ISO build)"
