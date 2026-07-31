#!/usr/bin/env bash
set -euo pipefail
exec "$(dirname "$0")/../scripts/dev/sync-airootfs-check.sh"
