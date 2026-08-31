#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="enigmarsos"
iso_label="ENIGMARSOS_$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="EnigmarsOS <https://enigmarsos.rishispace.dev>"
iso_application="EnigmarsOS Live/Install Medium"
iso_version="$(date --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
# Live medium bootloaders (mkarchiso). Installed systems use Limine via Calamares.
bootmodes=('bios.syslinux'
           'uefi.systemd-boot')
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
bootstrap_tarball_compression=('zstd' '-c' '-T0' '--auto-threads=logical' '--long' '-19')
file_permissions=(
  ["/usr/share/enigmarsos/scripts/install-limine.sh"]="0:0:755"
  ["/usr/share/enigmarsos/scripts/sync-esp-boot.sh"]="0:0:755"
  ["/usr/share/enigmarsos/scripts/seed-kernel.sh"]="0:0:755"
  ["/usr/share/enigmarsos/scripts/fix-mkinitcpio.sh"]="0:0:755"
  ["/usr/share/enigmarsos/scripts/post-install.sh"]="0:0:755"
  ["/usr/local/bin/enigmarsos-branding"]="0:0:755"
  ["/usr/share/libalpm/scripts/enigmarsos-os-release"]="0:0:755"
  ["/usr/share/libalpm/scripts/enigmarsos-sync-esp"]="0:0:755"
  ["/etc/shadow"]="0:0:400"
  ["/root"]="0:0:750"
  ["/root/.automated_script.sh"]="0:0:755"
  ["/root/.gnupg"]="0:0:700"
  ["/usr/local/bin/choose-mirror"]="0:0:755"
  ["/usr/local/bin/Installation_guide"]="0:0:755"
  ["/usr/local/bin/livecd-sound"]="0:0:755"
  ["/usr/local/bin/enigmarsos-welcome"]="0:0:755"
  ["/usr/local/bin/enigmars-util-autostart"]="0:0:755"
  ["/usr/local/bin/enigmarsos-plasma-defaults"]="0:0:755"
  ["/etc/skel/Desktop/org.enigmars.Util.desktop"]="0:0:755"
  ["/etc/skel/Desktop/install-enigmarsos.desktop"]="0:0:755"
  ["/usr/local/bin/enigmarsos-firstboot"]="0:0:755"
  ["/usr/local/bin/enigmarsos-setup-live-user"]="0:0:755"
)
