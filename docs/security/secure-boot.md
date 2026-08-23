# Secure Boot (sbctl)

EnigmarsOS does not ship Microsoft-enrolled images. Use [sbctl](https://github.com/Foxboron/sbctl) on an installed UEFI system. The installer uses **Limine** on the ESP (`/boot/efi/EFI/EnigmarsOS/` and `EFI/BOOT/`).

Full walkthrough (Setup Mode, enroll, sign, kernel updates):  
https://enigmarsos.rishispace.dev/docs#secure-boot

Short form:

```bash
sudo pacman -S sbctl
sudo sbctl status          # firmware must be in Setup Mode
sudo sbctl create-keys
sudo sbctl enroll-keys -m  # include Microsoft keys (GPU/Windows)

sudo sbctl sign -s /boot/efi/EFI/BOOT/BOOTX64.EFI
sudo sbctl sign -s /boot/efi/EFI/EnigmarsOS/BOOTX64.EFI
sudo sbctl sign -s /boot/efi/EFI/EnigmarsOS/vmlinuz-linux-enigmarsos
sudo sbctl sign -s /boot/vmlinuz-linux-enigmarsos
# also sign vmlinuz-linux on ESP and /boot if you use the fallback kernel

sudo sbctl verify
```

After kernel updates, `sync-esp-boot.sh` runs `sbctl sign-all` when sbctl is installed. If a signed boot fails, run `sudo sbctl sign-all` before the next reboot.

fwupd can update UEFI firmware on supported hardware; that may require re-enrolling keys.
