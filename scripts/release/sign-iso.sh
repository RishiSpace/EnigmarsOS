#!/usr/bin/env bash
set -euo pipefail
# Sign and checksum ISO artifacts
# Usage: sign-iso.sh out/*.iso

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <iso> [iso...]" >&2
  exit 1
fi

KEY="${ENIGMARSOS_GPG_KEY:-}"
for iso in "$@"; do
  [[ -f "$iso" ]] || { echo "Missing $iso" >&2; exit 1; }
  sha256sum "$iso" | tee "${iso}.sha256"
  if [[ -n "$KEY" ]]; then
    gpg --batch --yes --detach-sign -u "$KEY" "$iso"
  else
    echo "ENIGMARSOS_GPG_KEY not set; skipped gpg signature for $iso" >&2
  fi
done

# Aggregate sums
(cd "$(dirname "$1")" && sha256sum "$(basename "$1")" > SHA256SUMS)
echo "Done."
