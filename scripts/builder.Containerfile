FROM debian:trixie

RUN apt-get update -qq && \
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
        debhelper dpkg-dev git gnupg reprepro lintian \
        live-build mmdebstrap xorriso dosfstools mtools \
        grub-efi-amd64-bin grub-pc-bin grub2-common \
    && rm -rf /var/lib/apt/lists/*
