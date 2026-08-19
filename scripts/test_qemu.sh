#!/bin/sh
set -eu

here=$(cd "$(dirname "$0")" && pwd)
root=$(cd "$here/.." && pwd)
ovmf=/usr/share/edk2-ovmf/x64
qemu_dir="$root/build/qemu"
iso="$root/build/iso/koompi-os.iso"

[ -f "$iso" ] || { echo "no ISO at $iso -- run scripts/build_iso.sh first" >&2; exit 1; }

mkdir -p "$qemu_dir"
rm -f "$qemu_dir"/boot1.log "$qemu_dir"/boot2.log "$qemu_dir"/boot1.sock "$qemu_dir"/boot2.sock
qemu-img create -f qcow2 "$qemu_dir/target.qcow2" 20G >/dev/null
cp "$ovmf/OVMF_VARS.4m.fd" "$qemu_dir/OVMF_VARS.fd"

common_qemu() {
    qemu-system-x86_64 \
        -machine q35 -accel kvm -cpu host -m 4096 -smp 4 \
        -drive if=pflash,format=raw,readonly=on,file="$ovmf/OVMF_CODE.4m.fd" \
        -drive if=pflash,format=raw,file="$qemu_dir/OVMF_VARS.fd" \
        -drive file="$qemu_dir/target.qcow2",if=virtio,format=qcow2 \
        -netdev user,id=net0 -device virtio-net-pci,netdev=net0 \
        -display none -vga none -no-reboot \
        "$@"
}

cat > "$qemu_dir/boot1.sh" <<'PAYLOAD'
koompi-install <<'INSTALLER_EOF' > /root/install.log 2>&1
1
us
en_US.UTF-8
Asia/Phnom_Penh
1
ERASE /dev/vda
koompi-test
tester
testpass123
4
INSTALLER_EOF
echo "AUTOTEST_INSTALL_EXIT=$?"
mkdir -p /mnt/dev /mnt/dev/pts /mnt/proc /mnt/sys
mount --bind /dev /mnt/dev
mount --bind /dev/pts /mnt/dev/pts
mount --bind /proc /mnt/proc
mount --bind /sys /mnt/sys
mkdir -p /mnt/etc/systemd/system/serial-getty@ttyS0.service.d
cat > /mnt/etc/systemd/system/serial-getty@ttyS0.service.d/autotest.conf <<'GETTY_EOF'
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root -o '-p -- \\u' --keep-baud 115200,38400,9600 %I $TERM
GETTY_EOF
mkdir -p /mnt/etc/systemd/system/getty.target.wants
ln -sf /lib/systemd/system/serial-getty@.service /mnt/etc/systemd/system/getty.target.wants/serial-getty@ttyS0.service
chroot /mnt systemctl set-default graphical.target
umount /mnt/dev/pts /mnt/dev /mnt/proc /mnt/sys
echo "AUTOTEST_BOOT1_DONE"
poweroff
PAYLOAD

cat > "$qemu_dir/boot2.sh" <<'PAYLOAD'
systemctl is-system-running --wait; echo "AUTOTEST_SYSTEM_STATE=$?"
apt-get update -qq > /root/boot2.log 2>&1
pre_count=$(snapper -c root list --columns number 2>/dev/null | grep -c '^[0-9]')
apt-get install -y cowsay >> /root/boot2.log 2>&1
echo "AUTOTEST_APT_INSTALL=$?"
post_count=$(snapper -c root list --columns number 2>/dev/null | grep -c '^[0-9]')
echo "AUTOTEST_SNAPSHOT_DELTA=$((post_count - pre_count))"
vita rollback --yes > /root/vita-rollback.log 2>&1
echo "AUTOTEST_ROLLBACK=$?"
if grub-editenv /boot/grub/grubenv list | grep -q koompi_boot_pending; then
    echo "AUTOTEST_BOOT_PENDING_CLEARED=no"
else
    echo "AUTOTEST_BOOT_PENDING_CLEARED=yes"
fi
echo "AUTOTEST_BOOT2_DONE"
poweroff
PAYLOAD

echo "=== boot 1: install ==="
common_qemu \
    -cdrom "$iso" -boot order=d \
    -serial unix:"$qemu_dir/boot1.sock",server=on,wait=off &
qemu1_pid=$!
python3 "$here/qemu_console.py" "$qemu_dir/boot1.sock" "$qemu_dir/boot1.sh" "$qemu_dir/boot1.log" 1800 60
wait "$qemu1_pid" || true

echo "=== boot1.log tail ==="
tail -n 40 "$qemu_dir/boot1.log" || true

if ! grep -q "AUTOTEST_BOOT1_DONE" "$qemu_dir/boot1.log"; then
    echo "boot 1 did not reach AUTOTEST_BOOT1_DONE -- see $qemu_dir/boot1.log" >&2
    exit 1
fi

echo "=== boot 2: verify ==="
common_qemu \
    -serial unix:"$qemu_dir/boot2.sock",server=on,wait=off &
qemu2_pid=$!
python3 "$here/qemu_console.py" "$qemu_dir/boot2.sock" "$qemu_dir/boot2.sh" "$qemu_dir/boot2.log" 900 25
wait "$qemu2_pid" || true

echo "=== boot2.log tail ==="
tail -n 60 "$qemu_dir/boot2.log" || true

echo "=== results ==="
grep AUTOTEST_ "$qemu_dir/boot1.log" "$qemu_dir/boot2.log" || true
