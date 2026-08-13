# Recovery

Boot the EnigmarsOS ISO and use **Arch chroot** style recovery:

```bash
# Mount root (example — btrfs with @ subvolume)
sudo mount -o subvol=/@ /dev/rootPart /mnt
# or: sudo mount /dev/rootPart /mnt
sudo mkdir -p /mnt/boot/efi
sudo mount /dev/efiPart /mnt/boot/efi   # ESP (vfat)
sudo arch-chroot /mnt

# Kernel + initramfs on /boot, then stage onto ESP for Limine
pacman -Syu linux
mkinitcpio -P
/usr/share/enigmarsos/scripts/sync-esp-boot.sh

# Optional full Limine reinstall (also stages kernels)
# /usr/share/enigmarsos/scripts/install-limine.sh

exit
sudo umount -R /mnt
```

### Emergency mode after update

See [Troubleshooting — Emergency mode after update](../troubleshooting/README.md).

From the live USB you can also run the repair helper (prompts for devices):

```bash
sudo bash /usr/share/enigmarsos/scripts/../  # prefer:
# copy from repo if needed:
sudo bash scripts/install/repair-limine-boot.sh /dev/rootPart /dev/efiPart
```

Live medium includes GParted, testdisk, networking and editors.
