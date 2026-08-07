# Secure Boot

EnigmarsOS aims for Secure Boot *compatibility*:

1. Install in UEFI mode.
2. Use systemd-boot or Limine with signed artifacts when you enroll keys.
3. For full sbctl/preloader workflows, see the advanced guide once keys are published.

fwupd can update UEFI capsule firmware on supported hardware.
