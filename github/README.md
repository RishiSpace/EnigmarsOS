# GitHub project assets

Canonical workflows and issue templates live in **`../.github/`** (GitHub’s required path).

This directory holds supplementary project meta used in docs and mirrors:

- Release checklist notes

## Release checklist

1. `./scripts/dev/sync-airootfs-check.sh`
2. `./scripts/build/prepare-profile.sh`
3. Tag `vYYYY.MM.DD` (optional) or dispatch the **ISO** workflow
4. Build ISO via the **ISO** GitHub Action (`workflow_dispatch` or tag push)
5. Action uploads the ISO + `SHA256SUMS` to SourceForge only:
   - SFTP path: `/home/frs/project/enigmaos`
   - Download: https://sourceforge.net/projects/enigmaos/files/latest/download
6. On SourceForge, set the new ISO as the project **default** download if needed

**Do not** attach the ISO to a GitHub Release — assets are capped at 2 GiB; the image is ~5 GB. SourceForge is the only ISO distribution channel.
