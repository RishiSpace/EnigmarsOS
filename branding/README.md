# Branding

Canonical logo: **`../public/EnigmarsOS.png`**

Also mirrored as SVG: `logos/EnigmarsOS.svg`

## Palette

| Token | Hex |
|-------|-----|
| Background | `#000000` |
| Accent cyan | `#00E5FF` |
| Accent purple | `#7B2FFF` |
| Text | `#F5F5F5` |
| Muted | `#8A8A8A` |

Never ship placeholder logos. Never show "Arch Linux" in user-visible chrome.

## Plasma start menu (Kickoff)

Kickoff uses the FreeDesktop icon name `start-here-kde`. EnigmarsOS ships a thin icon theme
`themes/icons/EnigmarsOS` (inherits Papirus-Dark) that overrides `start-here-kde` / `start-here`
with the canonical logo. Default icon theme is set to **EnigmarsOS** in skel/`kdeglobals`,
`/etc/xdg/kdeglobals`, and the look-and-feel package.
