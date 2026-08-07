# EnigmarsOS custom packages

These PKGBUILDs produce the meta/branding layer on top of Arch.

| Package | Description |
|---------|-------------|
| `enigmarsos-filesystem` | Identity files (`os-release`, `issue`, `motd`) |
| `enigmarsos-settings` | Defaults: security, Plasma skel, NetworkManager |
| `enigmarsos-artwork` | Logos, wallpapers, color schemes |
| `enigmarsos-welcome` | Welcome Qt application |
| `enigmarsos-calamares-config` | Installer configuration |
| `enigmarsos-firefox-config` | Enterprise policies (privacy + uBlock) |
| `enigmarsos-hooks` | pacman hooks |
| `enigmarsos-keyring` | Signing keyring (populate at release) |

## Build locally

```bash
cd packages/enigmarsos-welcome
makepkg -si
```

Release engineering should publish them to `https://enigmarsos.rishispace.dev/repo/$arch`.
