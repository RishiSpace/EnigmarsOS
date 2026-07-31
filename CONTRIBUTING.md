# Contributing to EnigmaOS

Thank you for helping build a polished, privacy-first Arch-based OS.

## Rules of the road

1. **Upstream first** — reuse Arch packages; avoid unnecessary forks.
2. **Philosophy filter** — every change should improve privacy, security, UX, performance, simplicity or long-term maintainability.
3. **No telemetry** — reject analytics, advertising and forced accounts.
4. **Branding** — visible strings say EnigmaOS; logo is `public/EnigmaOS.png` only.
5. **No placeholders** — do not merge broken configs, TODOs-as-features or dead code.
6. **Modular** — prefer packages under `packages/` over one-off hacks in airootfs.

## Workflow

```bash
./scripts/dev/sync-airootfs-check.sh
./scripts/build/prepare-profile.sh
```


## Package list changes

- Official repo packages → `packages.x86_64`
- AUR/external → `packages.aur.x86_64` + plan for custom repo packaging
