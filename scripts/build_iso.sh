#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
zig="$root/.zig-toolchain/zig-x86_64-linux-0.14.1/zig"
image=koompi-builder
work="$root/build/live-build"

podman image exists "$image" || podman build -t "$image" -f "$here/builder.Containerfile" "$root"

( cd "$root/vita" && "$zig" build -Doptimize=ReleaseSafe )
( cd "$root/installer" && "$zig" build -Doptimize=ReleaseSafe )

podman run --init --rm -v "$root":/repo:Z -w /repo "$image" sh repo/build-repo.sh

rm -rf "$work"
cp -a "$root/base/live-build" "$work"

chroot_share="$work/config/includes.chroot/usr/share/koompi-os"
mkdir -p "$chroot_share" "$work/config/includes.chroot/usr/bin" \
    "$work/config/includes.chroot/usr/share/keyrings" \
    "$work/config/includes.chroot/etc/apt/sources.list.d" \
    "$work/config/packages.chroot"

cp -a "$root/editions" "$chroot_share/editions"
mkdir -p "$chroot_share/base"
cp "$root/base/packages.list" "$chroot_share/base/packages.list"
cp -a "$root/base/overlay" "$chroot_share/base/overlay"
mkdir -p "$chroot_share/repo"
cp -a "$root/build/repo/dists" "$root/build/repo/pool" "$chroot_share/repo/"

cp "$root/vita/zig-out/bin/vita" "$work/config/includes.chroot/usr/bin/vita"
cp "$root/installer/zig-out/bin/koompi-install" "$work/config/includes.chroot/usr/bin/koompi-install"
cp "$root/packages/koompi-archive-keyring/usr/share/keyrings/koompi-archive-keyring.gpg" \
    "$work/config/includes.chroot/usr/share/keyrings/koompi-archive-keyring.gpg"
cp "$root/build/debs/koompi-archive-keyring_"*.deb "$work/config/packages.chroot/"

cat > "$work/config/includes.chroot/etc/apt/sources.list.d/koompi-repo.list" <<'EOF'
deb [signed-by=/usr/share/keyrings/koompi-archive-keyring.gpg] file:///usr/share/koompi-os/repo trixie main
EOF

podman run --init --rm --privileged -v "$work":/build:Z -w /build "$image" sh -c '
    lb config
    lb build
'

mkdir -p "$root/build/iso"
mv "$work"/*.iso "$root/build/iso/koompi-os.iso"
echo "ISO: $root/build/iso/koompi-os.iso"
