# EnigmarsOS

Arch-based Linux with KDE Plasma 6. Privacy defaults, Calamares installer, Limine on the installed system.

Default kernel is [`linux-enigmarsos`](https://github.com/RishiSpace/linux-enigmarsos) (Arch + BORE). Stock `linux` stays around as a fallback.

## Layout

```
archiso/           mkarchiso profile
packages/          custom PKGBUILDs
branding/          logos
themes/            Plasma / icons
plymouth/          boot splash
calamares/         installer
scripts/           build and install helpers
docs/              user docs
docker/            ISO build image
public/EnigmarsOS.png
packages.x86_64    ISO package list
profiledef.sh      ISO identity
```

## Build the ISO

Docker (easiest):

```bash
./scripts/build/prepare-profile.sh
./scripts/build/docker-build-iso.sh
```

or `make iso-docker`. Output is in `out/`.

On Arch:

```bash
sudo pacman -S --needed archiso git squashfs-tools dosfstools libisoburn mtools
./scripts/build/prepare-profile.sh
sudo ./scripts/build/build-iso.sh
```

Sign an ISO:

```bash
export ENIGMARSOS_GPG_KEY=YOUR_KEY_ID
./scripts/release/sign-iso.sh out/enigmarsos-*.iso
```

## Packages

| Package | What it is |
|---------|------------|
| `enigmarsos-filesystem` | os-release, issue, motd |
| `enigmarsos-settings` | Plasma / security defaults |
| `enigmarsos-artwork` | logos, wallpapers, colors |
| `enigmarsos-welcome` | welcome app |
| `enigmarsos-calamares-config` | installer branding |
| `enigmarsos-firefox-config` | Firefox policies + uBlock |
| `enigmarsos-hooks` | pacman hooks (ESP kernel sync, …) |
| `enigmarsos-keyring` | package signing |

## Live USB

| | |
|--|--|
| User | `live` / `live` |
| Desktop | Plasma 6 (Wayland) |
| Installer | Calamares (`sudo calamares`) |

## Docs

[`docs/`](docs/README.md) covers install, gaming, recovery, and troubleshooting.

Before a PR: `./scripts/dev/sync-airootfs-check.sh`.

## License

GPL-3.0-or-later for EnigmarsOS packaging and tooling. Upstream keeps its own licenses. Not affiliated with Arch Linux.

## Links

- Site / docs: https://enigmarsos.rishispace.dev
- Issues: https://github.com/RishiSpace/EnigmarsOS/issues
