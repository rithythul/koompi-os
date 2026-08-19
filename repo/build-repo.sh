#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
keydir="$root/build/repo-signing"
basedir="$root/build/repo"
keyring="$root/packages/koompi-archive-keyring/usr/share/keyrings/koompi-archive-keyring.gpg"

mkdir -p "$keydir"
chmod 700 "$keydir"
export GNUPGHOME="$keydir"

if ! gpg --list-secret-keys --with-colons 2>/dev/null | grep -q '^sec'; then
    batch=$(mktemp)
    cat > "$batch" <<EOF
%no-protection
Key-Type: RSA
Key-Length: 3072
Name-Real: KOOMPI Archive
Name-Email: packages@koompi.org
Expire-Date: 0
%commit
EOF
    gpg --batch --generate-key "$batch"
    rm -f "$batch"
fi

mkdir -p "$(dirname "$keyring")"
gpg --export > "$keyring"

for pkg in koompi-snapper-hooks koompi-boot-success koompi-archive-keyring; do
    ( cd "$root/packages/$pkg" && dpkg-buildpackage -us -uc -b )
done
sh "$root/packages/grub-btrfs/build.sh"

mkdir -p "$root/build/debs"
find "$root/packages" -maxdepth 1 -name '*.deb' -exec mv {} "$root/build/debs/" \;
find "$root/packages" -maxdepth 1 \( -name '*.changes' -o -name '*.buildinfo' \) -delete

mkdir -p "$basedir"
for deb in "$root"/build/debs/*.deb; do
    reprepro --basedir "$basedir" --confdir "$here/conf" includedeb trixie "$deb"
done

reprepro --basedir "$basedir" --confdir "$here/conf" export trixie
reprepro --basedir "$basedir" --confdir "$here/conf" check trixie
