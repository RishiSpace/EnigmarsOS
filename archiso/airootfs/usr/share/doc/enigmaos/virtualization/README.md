# Virtualization

## Enable libvirt

```bash
sudo systemctl enable --now libvirtd
sudo usermod -aG libvirt,kvm $USER
# re-login
virt-manager
```

## Nested virtualization

- Intel: `modprobe kvm_intel nested=1`
- AMD: `modprobe kvm_amd nested=1`

## Firmware

OVMF (UEFI) firmware is installed via `edk2-ovmf` for modern guest VMs.
