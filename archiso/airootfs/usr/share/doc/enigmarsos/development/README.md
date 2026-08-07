# Development on EnigmarsOS

Toolchains are preinstalled so you can start coding immediately.

## Languages & tools

- C/C++: GCC, Clang, LLVM, LLD, CMake, Meson, Ninja, Make
- Rust: `rustup` (install toolchains with `rustup default stable`)
- Go: system `go`
- Node.js: npm, pnpm, yarn
- Python: pip, pipx, uv
- Java: OpenJDK
- Editors: Neovim, VSCodium
- Data: SQLite, PostgreSQL client, MySQL/MariaDB client
- CLI: ripgrep, fd, bat, fzf, zoxide, starship, jq, tmux, btop, fastfetch

## Containers & VMs

- Docker & Docker Compose (enable with `sudo systemctl enable --now docker`)
- Podman & podman-compose
- QEMU/KVM, libvirt, virt-manager, OVMF

Add your user to `docker` and `libvirt` groups (Calamares does this by default for new users).
