#!/bin/bash
# KOOMPI OS ISO Build Script
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_ROOT/build"
OUT_DIR="$PROJECT_ROOT/out"
ISO_DIR="$PROJECT_ROOT/iso"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() { echo -e "${GREEN}[KOOMPI]${NC} $1"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# Check if running as root
check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

# Check dependencies
check_deps() {
    log "Checking dependencies..."
    
    local deps=(mkarchiso mksquashfs)
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            error "Missing dependency: $dep. Install with: pacman -S archiso"
        fi
    done
    
    log "All dependencies satisfied"
}

# Build ISO
build_iso() {
    log "Building KOOMPI OS ISO..."
    
    mkdir -p "$BUILD_DIR" "$OUT_DIR"
    
    # Clean old profile to ensure we use fresh config
    rm -rf "$BUILD_DIR/profile"
    
    # Optional: Clean work directory if build fails or for fresh start
    # Uncomment next line to ALWAYS start from scratch (slower but safer)
    # rm -rf "$BUILD_DIR/work"
    
    # Copy ISO profile
    cp -r "$ISO_DIR" "$BUILD_DIR/profile"

    # Build with mkarchiso
    if ! mkarchiso -v -w "$BUILD_DIR/work" -o "$OUT_DIR" "$BUILD_DIR/profile"; then
        warn "Build failed. Checking for stale mounts in $BUILD_DIR/work..."
        # Attempt to unmount anything left behind
        mount | grep "$BUILD_DIR/work" | cut -d' ' -f3 | sort -r | xargs -r umount -l || true
        error "ISO build failed. You might need to run: sudo $0 clean"
    fi
    
    # Rename output
    local iso_file=$(ls "$OUT_DIR"/*.iso 2>/dev/null | head -1)
    if [[ -n "$iso_file" ]]; then
        local new_name="koompi-os-$(date +%Y.%m)-x86_64.iso"
        if [[ "$(basename "$iso_file")" != "$new_name" ]]; then
            mv "$iso_file" "$OUT_DIR/$new_name"
        fi
        log "ISO created: $OUT_DIR/$new_name"
    fi
}

# Clean build artifacts
clean() {
    log "Cleaning build artifacts..."
    rm -rf "$BUILD_DIR" "$OUT_DIR"
    log "Clean complete"
}

# Main
main() {
    local cmd="${1:-all}"
    
    case "$cmd" in
        all)
            check_root
            check_deps
            build_iso
            ;;
        iso)
            check_root
            check_deps
            build_iso
            ;;
        clean)
            clean
            ;;
        *)
            echo "Usage: $0 {all|iso|clean}"
            exit 1
            ;;
    esac
}

main "$@"
