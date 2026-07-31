# Installing EnigmaOS

## Requirements

- 64-bit x86_64 CPU
- 4 GB RAM minimum (8 GB recommended)
- 20 GB free disk space (40+ GB recommended for gaming/dev)
- USB 4 GB+ or virtual optical drive
- UEFI (recommended) or legacy BIOS

## Write the ISO

```bash
# Linux
sudo dd if=enigmaos-YYYY.MM.DD-x86_64.iso of=/dev/sdX bs=4M status=progress oflag=sync

# Or use Ventoy / balenaEtcher / Fedora Media Writer
```

Verify checksums before writing:

```bash
sha256sum -c SHA256SUMS
gpg --verify enigmaos-*.iso.sig
```

## Installer (Calamares)

1. Boot the USB and choose **EnigmaOS**.
2. Launch **Install EnigmaOS** from the desktop (or run `sudo calamares`).
3. Select language, region and keyboard.
4. Partition:
   - **Erase disk** for a clean install (optionally enable LUKS).
   - **Manual** for dual-boot or custom layouts.
   - Default filesystem: **Btrfs** (recommended) or ext4/XFS.
5. Create your user (zsh is default shell).
6. Confirm and install.
7. Reboot into your new system.

## Post-install

The **Welcome to EnigmaOS** app opens on first login:

- Update the system
- Review gaming/driver status
- Open documentation and community links

Flatpak Flathub is preconfigured. Firmware updates appear in Discover when `fwupd` detects devices.
