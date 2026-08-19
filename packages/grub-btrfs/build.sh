#!/bin/sh
set -eu

upstream_repo=https://github.com/Antynea/grub-btrfs.git
upstream_tag=v4.14
upstream_sha=2fcfbe967637166b88dadd49c834807243a941bf

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/../.." && pwd)
src="$root/build/grub-btrfs-src"
out="$root/build/debs"

rm -rf "$src"
git clone --branch "$upstream_tag" --depth 1 "$upstream_repo" "$src"
actual_sha=$(git -C "$src" rev-parse HEAD)
if [ "$actual_sha" != "$upstream_sha" ]; then
    echo "grub-btrfs $upstream_tag resolved to $actual_sha, expected $upstream_sha -- refusing to build an unpinned tree" >&2
    exit 1
fi
rm -rf "$src/.git"

cp -a "$here/debian" "$src/debian"

mkdir -p "$out"
( cd "$src" && dpkg-buildpackage -us -uc -b )
mv "$root/build"/grub-btrfs_*.deb "$out/"
