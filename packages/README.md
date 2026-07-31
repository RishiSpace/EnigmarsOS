# EnigmaOS custom packages

These PKGBUILDs produce the meta/branding layer on top of Arch.

| Package | Description |
|---------|-------------|
| `enigmaos-filesystem` | Identity files (`os-release`, `issue`, `motd`) |
| `enigmaos-settings` | Defaults: security, Plasma skel, NetworkManager |
| `enigmaos-artwork` | Logos, wallpapers, color schemes |
| `enigmaos-welcome` | Welcome Qt application |
| `enigmaos-calamares-config` | Installer configuration |
| `enigmaos-firefox-config` | Enterprise policies (privacy + uBlock) |
| `enigmaos-hooks` | pacman hooks |
| `enigmaos-keyring` | Signing keyring (populate at release) |

## Build locally

```bash
cd packages/enigmaos-welcome
makepkg -si
```

Release engineering should publish them to `https://enigmaos.rishispace.dev/repo/$arch`.
