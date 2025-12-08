#!/bin/bash
# Test KOOMPI OS ISO in QEMU
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
OUT_DIR="$PROJECT_ROOT/out"

# Find latest ISO
ISO_FILE=$(ls -t "$OUT_DIR"/*.iso 2>/dev/null | head -1)

if [[ -z "$ISO_FILE" ]]; then
    echo "No ISO found in $OUT_DIR"
    echo "Run ./scripts/build-iso.sh first"
    exit 1
fi

echo "Testing: $ISO_FILE"

# Create temporary disk image
DISK_IMG=$(mktemp /tmp/koompi-test-XXXXXX.qcow2)
qemu-img create -f qcow2 "$DISK_IMG" 20G

# Run QEMU
qemu-system-x86_64 \
    -enable-kvm \
    -m 4G \
    -smp 4 \
    -cpu host \
    -drive file="$DISK_IMG",format=qcow2 \
    -cdrom "$ISO_FILE" \
    -boot d \
    -vga virtio \
    -display gtk \
    -usb \
    -device usb-tablet \
    -netdev user,id=net0 \
    -device virtio-net-pci,netdev=net0 \
    -bios /usr/share/ovmf/x64/OVMF.fd

# Cleanup
rm -f "$DISK_IMG"
