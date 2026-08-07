# Recovery

Boot the EnigmarsOS ISO and use **Arch chroot** style recovery:

```bash
# Mount root (example)
sudo mount /dev/rootPart /mnt
sudo mount /dev/efiPart /mnt/boot/efi   # if separate EFI
sudo arch-chroot /mnt
mkinitcpio -P
# reinstall bootloader as needed
```

Live medium includes GParted, testdisk, networking and editors.
