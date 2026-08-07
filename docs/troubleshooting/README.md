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
