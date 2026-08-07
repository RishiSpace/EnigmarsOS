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
