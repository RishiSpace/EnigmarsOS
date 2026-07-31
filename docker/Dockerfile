# EnigmaOS ISO build image — Arch Linux + archiso + Calamares (vendored)
FROM archlinux:latest

LABEL org.opencontainers.image.title="EnigmaOS ISO Builder" \
      org.opencontainers.image.description="Privileged Arch environment for mkarchiso" \
      org.opencontainers.image.source="https://github.com/RishiSpace/EnigmaOS"

RUN printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf

RUN pacman-key --init && pacman-key --populate archlinux \
    && pacman -Syu --noconfirm \
    && pacman -S --noconfirm --needed \
        archiso base-devel git squashfs-tools dosfstools libisoburn mtools \
        erofs-utils grub edk2-shell pacman-contrib wget curl rsync jq which \
        arch-install-scripts \
        cmake ninja extra-cmake-modules boost yaml-cpp kpmcore \
        kconfig kcoreaddons kcrash ki18n kparts kwidgetsaddons solid \
        polkit-qt6 qt6-base qt6-declarative qt6-svg qt6-tools qt6-translations \
        appstream-qt python python-jsonschema networkmanager upower \
        kservice kwallet kirigami kdbusaddons kio kxmlgui libpwquality \
        boost-libs \
    && pacman -Scc --noconfirm

RUN useradd -m -G wheel builder \
    && echo 'builder ALL=(ALL) NOPASSWD: ALL' >/etc/sudoers.d/builder \
    && mkdir -p /opt/enigmaos-repo /home/builder/build \
    && chown -R builder:builder /opt/enigmaos-repo /home/builder

# Vendored sources (avoids flaky Codeberg downloads during image build)
COPY cache/calamares-3.3.14.tar.gz cache/PKGBUILD.calamares /home/builder/build/
# Build ckbcomp from AUR + calamares from vendored tarball
USER builder
WORKDIR /home/builder/build

RUN set -euo pipefail \
    && git clone --depth 1 https://aur.archlinux.org/ckbcomp.git \
    && cd ckbcomp && makepkg -s --noconfirm \
    && sudo pacman -U --noconfirm ./*.pkg.tar.zst \
    && cp -v ./*.pkg.tar.zst /opt/enigmaos-repo/ \
    && cd /home/builder/build \
    && mkdir -p calamares-pkg && cd calamares-pkg \
    && cp ../PKGBUILD.calamares PKGBUILD \
    && cp ../calamares-3.3.14.tar.gz . \
    && makepkg -s --noconfirm \
    && sudo pacman -U --noconfirm ./*.pkg.tar.zst \
    && cp -v ./*.pkg.tar.zst /opt/enigmaos-repo/ \
    && cd /opt/enigmaos-repo \
    && repo-add enigmaos-local.db.tar.gz ./*.pkg.tar.zst \
    && ls -lh /opt/enigmaos-repo

USER root
WORKDIR /build

RUN printf '\n[enigmaos-local]\nSigLevel = Optional TrustAll\nServer = file:///opt/enigmaos-repo\n' >> /etc/pacman.conf \
    && pacman -Sy --noconfirm \
    && pacman -Si calamares | head -10

COPY entrypoint.sh /usr/local/bin/enigmaos-iso-entrypoint
RUN chmod +x /usr/local/bin/enigmaos-iso-entrypoint

ENTRYPOINT ["/usr/local/bin/enigmaos-iso-entrypoint"]
