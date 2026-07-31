# EnigmaOS

**Privacy first · Secure by default · Ready immediately**

EnigmaOS is a production-minded Linux distribution based on Arch Linux with KDE Plasma 6. It is **not** a casual remaster: the repository is structured for long-term packaging, branded install media, reproducible ISO builds and a coherent desktop experience.

> Stay as close to upstream Arch as reasonably possible. Customize only where it improves UX, security, privacy, performance or branding.

## Design principles

1. **Privacy first** — no telemetry, no ads, no forced accounts  
2. **Secure by default** — AppArmor, UFW, LUKS-ready, hardened sysctl  
3. **Ready immediately** — gaming, development, office, multimedia out of the box  
4. **Developer friendly** — full toolchains without bootstrap rituals  
5. **Gaming ready** — Steam/Lutris/Heroic/Proton stack preinstalled  
6. **Beautiful minimalism** — AMOLED black, cyan & purple accents, consistent branding  

## Repository layout

```
EnigmaOS/
├── archiso/           # mkarchiso profile (airootfs, boot loaders)
├── packages/          # Custom PKGBUILDs (welcome, artwork, settings, …)
├── branding/          # Logos and brand assets
├── wallpapers/        # Desktop wallpapers
├── themes/            # Plasma, Konsole, etc.
├── plymouth/          # Boot splash
├── sddm/              # Display manager theme
├── calamares/         # Installer settings + branding
├── scripts/           # Build, release and developer tooling
├── docs/              # End-user documentation
├── docker/            # Arch container image for ISO builds
├── public/EnigmaOS.png
├── packages.x86_64    # ISO package list
├── profiledef.sh      # ISO identity
└── README.md
```

## Build the ISO (Docker — recommended)

Requires Docker with privilege support (loop mounts, pacstrap):

```bash
# Prepare branding into the archiso profile
./scripts/build/prepare-profile.sh

# Build inside an Arch Linux container
./scripts/build/docker-build-iso.sh
```

Artifacts land in `out/`. Equivalent Make target:

```bash
make iso-docker
```

### Native Arch host

```bash
sudo pacman -S --needed archiso git squashfs-tools dosfstools libisoburn mtools
./scripts/build/prepare-profile.sh
sudo ./scripts/build/build-iso.sh
```

### Sign release artifacts

```bash
export ENIGMAOS_GPG_KEY=YOUR_KEY_ID
./scripts/release/sign-iso.sh out/enigmaos-*.iso
```

## Custom packages

| Package | Role |
|---------|------|
| `enigmaos-filesystem` | `os-release`, issue, motd |
| `enigmaos-settings` | Secure defaults, Plasma skel |
| `enigmaos-artwork` | Logos, wallpapers, colors |
| `enigmaos-welcome` | Welcome application |
| `enigmaos-calamares-config` | Installer branding |
| `enigmaos-firefox-config` | Privacy policies + uBlock |
| `enigmaos-hooks` | pacman hooks |
| `enigmaos-keyring` | Package signing keyring |

## Live session

| Item | Value |
|------|--------|
| User | `live` / `live` |
| Desktop | Plasma 6 (Wayland) |
| Installer | Calamares (`sudo calamares`) |
| Branding | EnigmaOS (no visible Arch labels) |

## Documentation

See [`docs/`](docs/README.md) for installation, gaming, development, virtualization, security, recovery, snapshots, updates and troubleshooting.

## Contributing

1. Keep changes modular and documented.  
2. Prefer upstream packages over forks.  
3. Never reintroduce telemetry or insecure defaults.  
4. Preserve branding consistency (logo: `public/EnigmaOS.png`).  
5. Run `./scripts/dev/sync-airootfs-check.sh` before opening a PR.

## License

GPL-3.0-or-later for EnigmaOS-specific packaging, branding integration and tooling. Upstream components retain their own licenses. Arch Linux is a trademark of Aaron Griffin and Judd Vinet; EnigmaOS is an independent project and is not affiliated with Arch Linux.

## Links

- Docs: https://enigmaos.rishispace.dev/docs  
- Issues: https://github.com/RishiSpace/EnigmaOS/issues  
