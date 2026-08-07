# Gaming on EnigmarsOS

Gaming is a first-class citizen. The stack is preinstalled.

## Included

| Tool | Purpose |
|------|---------|
| Steam | Proton & native titles |
| Lutris | GOG, battle.net, emulators, custom runners |
| Heroic | Epic / GOG launcher |
| Wine / Winetricks | Windows compatibility |
| DXVK / VKD3D-Proton | D3D11/12 → Vulkan |
| Gamescope | Nested compositor / Steam Deck-like session |
| GameMode | Transient performance profile |
| MangoHud | Overlay metrics |
| ProtonUp-Qt | Manage Proton-GE |

## GPU notes

- **AMD**: Mesa + `vulkan-radeon` (and lib32) — works out of the box.
- **Intel**: Mesa + `vulkan-intel`.
- **NVIDIA**: Nouveau/Mesa work for basic use; install proprietary `nvidia` / `nvidia-open` packages for best performance.

## Tips

```bash
# Launch with GameMode
gamemoderun %command%

# MangoHud
MANGOHUD=1 %command%

# Gamescope example
gamescope -f -w 1920 -h 1080 -- %command%
```

Enable Steam Play for all titles in Steam settings for Proton by default.
