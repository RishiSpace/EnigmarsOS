# Troubleshooting

## Black screen after login (Wayland)

- At SDDM, choose a X11 Plasma session if needed.
- Update GPU drivers; for NVIDIA prefer proprietary modules + modesetting.

## Wi-Fi missing

```bash
nmcli device
sudo systemctl status NetworkManager
```

## Firewall blocking a service

```bash
sudo ufw status verbose
sudo ufw allow 22/tcp   # example
```

## Emergency mode after update (`Failed to mount /boot/efi`)

Also shows **Failed to start CLI Netfilter Manager** (that is **UFW** — secondary).

### Cause

Limine boots the kernel from the **ESP** (`/boot/efi`). `pacman -Syu` / Discover
installs the new kernel only under **`/boot` on the root filesystem** (usually
btrfs). Without staging, the ESP still has the **old** kernel. That kernel has no
matching modules after the upgrade → `vfat` cannot load → `/boot/efi` mount
fails → emergency mode.

New installs ship a pacman hook that runs
`/usr/share/enigmarsos/scripts/sync-esp-boot.sh` after kernel updates.

### Fix from the live USB (installed system already broken)

```bash
# Replace devices with yours (lsblk -f)
sudo mount -o subvol=/@ /dev/nvme0n1p2 /mnt          # btrfs root @
# or: sudo mount /dev/nvme0n1p2 /mnt                 # ext4/xfs
sudo mount /dev/nvme0n1p1 /mnt/boot/efi              # ESP (vfat)
sudo arch-chroot /mnt

# Install/refresh kernel + restage to ESP
pacman -Syu linux
/usr/share/enigmarsos/scripts/sync-esp-boot.sh
# If the script is missing (older ISO), copy it from a new ISO or from:
#   https://github.com/RishiSpace/EnigmarsOS (scripts/install/sync-esp-boot.sh)

exit
sudo umount -R /mnt
sudo reboot
```

### Fix if you can still reach a root shell with modules working

```bash
sudo mount /boot/efi
sudo /usr/share/enigmarsos/scripts/sync-esp-boot.sh
# or, on systems that only have the repair helper from the ISO tree:
# sudo bash /path/to/repair-limine-boot.sh
```

After a good boot, every future `pacman -Syu` should print
**Staging kernel/initramfs onto ESP for Limine...**

## Reinstall bootloader

See [Recovery](../recovery/README.md).

## Calamares: Package Manager error (pacman exit 1)

Usually the `packages` job tried a **critical** `pacman -S` (e.g. reinstall
`linux`) inside the target without a working network/keyring/mirrors.

EnigmarsOS install flow is offline-safe:

1. `seed-kernel` copies `vmlinuz-linux` from the live session into the target
2. `packages` only **try_remove**s live-only packages (failures ignored)
3. `fix-mkinitcpio` rewrites the archiso preset to default/fallback
4. `initcpio` builds initramfs

If you still see package errors, check `/var/log/Calamares.log` on the live
session for the exact pacman stderr.
