#!/usr/bin/env bash
# ==============================================================================
# ARMOR OS: Automated Live-Build Generator for Debian 12 (Bookworm) Hardened ISO
# ==============================================================================
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive
BUILD_DIR="$(pwd)/armor-build"

echo "[+] Initializing ARMOR ISO Build Environment in ${BUILD_DIR}..."

# Step 1: Install prerequisite packages if running in Debian/Ubuntu build container or WSL2
if command -v apt-get >/dev/null 2>&1; then
    sudo apt-get update
    sudo apt-get install -y --no-install-recommends \
        live-build \
        debootstrap \
        xorriso \
        squashfs-tools \
        isolinux \
        syslinux-efi \
        grub-pc-bin \
        grub-efi-amd64-bin \
        mtools \
        dosfstools \
        cryptsetup-bin
fi

# Step 2: Clean and recreate live-build directory
sudo rm -rf "${BUILD_DIR}"
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Step 3: Configure live-build for Debian 12 (Bookworm) amd64 EFI+BIOS
lb config \
    --distribution bookworm \
    --architectures amd64 \
    --archive-areas "main contrib non-free non-free-firmware" \
    --bootloader grub-efi \
    --binary-images iso-hybrid \
    --iso-application "ARMOR Secure Enterprise OS" \
    --iso-publisher "ARMOR Security Team" \
    --iso-volume "ARMOR_V1" \
    --memtest none \
    --security true \
    --updates true \
    --apt-recommends false \
    --system live

echo "[+] Populating package lists and chroot inclusions..."
# Package definitions and file inclusions are populated via the build scripts
