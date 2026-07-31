# GitHub project assets

Canonical workflows and issue templates live in **`../.github/`** (GitHub’s required path).

This directory holds supplementary project meta used in docs and mirrors:

- Release checklist notes

## Release checklist

1. `./scripts/dev/sync-airootfs-check.sh`
2. `./scripts/build/prepare-profile.sh`
3. Tag `vYYYY.MM.DD`
4. Build ISO (`make iso` on Arch host) or dispatch **ISO** workflow
5. `./scripts/release/sign-iso.sh out/*.iso`
6. Publish GitHub Release with ISO + `SHA256SUMS` + signatures
