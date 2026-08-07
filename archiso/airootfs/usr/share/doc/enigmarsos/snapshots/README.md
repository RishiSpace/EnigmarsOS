# Snapshots

When installing with **Btrfs**, consider enabling Snapper post-install:

```bash
sudo pacman -S snapper snap-pac
sudo snapper -c root create-config /
```

Timeshift is also available for GUI snapshot workflows.
