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

# Find OVMF (UEFI Firmware)
OVMF_PATH=""
for path in /usr/share/edk2/x64/OVMF.4m.fd /usr/share/ovmf/x64/OVMF.fd /usr/share/edk2-ovmf/x64/OVMF.fd /usr/share/OVMF/OVMF_CODE.fd; do
    if [[ -f "$path" ]]; then
        OVMF_PATH="$path"
        break
    fi
done

QEMU_ARGS=(
    -enable-kvm
    -m 4G
    -smp 4
    -cpu host
    -drive file="$DISK_IMG",format=qcow2
    -cdrom "$ISO_FILE"
    -boot d
    -vga virtio
    -usb
    -device usb-tablet
    -netdev user,id=net0
    -device virtio-net-pci,netdev=net0
)

# Try different display backends
if qemu-system-x86_64 -display help 2>&1 | grep -q "sdl"; then
    QEMU_ARGS+=(-display sdl,gl=on)
elif qemu-system-x86_64 -display help 2>&1 | grep -q "gtk"; then
    QEMU_ARGS+=(-display gtk,gl=on)
else
    QEMU_ARGS+=(-display default)
fi

if [[ -n "$OVMF_PATH" ]]; then
    echo "Using UEFI: $OVMF_PATH"
    QEMU_ARGS+=(-bios "$OVMF_PATH")
else
    echo "WARNING: OVMF not found, falling back to BIOS legacy boot"
fi

# Run QEMU
qemu-system-x86_64 "${QEMU_ARGS[@]}"

# Cleanup
rm -f "$DISK_IMG"
