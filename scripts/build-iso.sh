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

# Build Rust components
build_rust() {
    log "Building Rust components..."
    
    cd "$PROJECT_ROOT/rust"
    
    if ! command -v cargo &> /dev/null; then
        warn "Rust not installed, skipping Rust build"
        return
    fi
    
    cargo build --release
    
    log "Rust build complete"
}

# Build Python wheel
build_python() {
    log "Building Python packages..."
    
    cd "$PROJECT_ROOT/python"
    
    # Build each package
    for pkg in koompi-ai koompi-cli; do
        if [[ -d "$pkg" ]]; then
            cd "$pkg"
            python -m build --wheel
            cd ..
        fi
    done
    
    log "Python build complete"
}

# Build custom packages (PKGBUILDs)
build_packages() {
    log "Building KOOMPI packages..."
    
    local pkg_dir="$PROJECT_ROOT/packages"
    local repo_dir="$pkg_dir/repo"
    
    mkdir -p "$repo_dir"
    
    # Build each package
    for pkg in "$pkg_dir"/*/; do
        if [[ -f "$pkg/PKGBUILD" ]]; then
            log "Building $(basename "$pkg")..."
            cd "$pkg"
            makepkg -sf --noconfirm
            mv *.pkg.tar.zst "$repo_dir/" 2>/dev/null || true
            cd "$PROJECT_ROOT"
        fi
    done
    
    # Create repo database
    cd "$repo_dir"
    repo-add koompi.db.tar.gz *.pkg.tar.zst 2>/dev/null || true
    
    log "Package build complete"
}

# Build ISO
build_iso() {
    log "Building KOOMPI OS ISO..."
    
    mkdir -p "$BUILD_DIR" "$OUT_DIR"
    
    # Copy ISO profile
    cp -r "$ISO_DIR" "$BUILD_DIR/profile"

    # Copy Rust binaries to airootfs
    log "Copying Rust binaries to ISO..."
    local bin_dir="$BUILD_DIR/profile/airootfs/usr/local/bin"
    mkdir -p "$bin_dir"
    
    for binary in koompi-shell koompi-daemon; do
        if [[ -f "$PROJECT_ROOT/rust/target/release/$binary" ]]; then
            cp "$PROJECT_ROOT/rust/target/release/$binary" "$bin_dir/"
            chmod +x "$bin_dir/$binary"
            log "Copied $binary"
        else
            warn "$binary binary not found. Did you run 'build_rust'?"
        fi
    done

    # Copy Python wheels
    log "Copying Python wheels to ISO..."
    local wheel_dir="$BUILD_DIR/profile/airootfs/usr/share/koompi/wheels"
    mkdir -p "$wheel_dir"
    
    if ls "$PROJECT_ROOT/python"/*/dist/*.whl 1> /dev/null 2>&1; then
        cp "$PROJECT_ROOT/python"/*/dist/*.whl "$wheel_dir/"
        log "Copied Python wheels"
    else
        warn "No Python wheels found. Did you run 'build_python'?"
    fi
    
    # Build with mkarchiso
    mkarchiso -v -w "$BUILD_DIR/work" -o "$OUT_DIR" "$BUILD_DIR/profile"
    
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
            build_rust
            build_python
            build_packages
            build_iso
            ;;
        rust)
            build_rust
            ;;
        python)
            build_python
            ;;
        packages)
            build_packages
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
            echo "Usage: $0 {all|rust|python|packages|iso|clean}"
            exit 1
            ;;
    esac
}

main "$@"
