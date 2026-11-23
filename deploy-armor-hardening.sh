#!/usr/bin/env bash
# ==============================================================================
# ARMOR OS: Automated Post-Install Provisioning & Hardening Deployment Script
# Applies all ARMOR hardening configurations to an installed Debian 12 system
# ==============================================================================
set -euo pipefail

echo "======================================================================"
echo "          ARMOR OS POST-INSTALL HARDENING DEPLOYMENT                  "
echo "======================================================================"

if [ "$(id -u)" -ne 0 ]; then
    echo "[ERROR] This installer must be executed as root." >&2
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${SCRIPT_DIR}/config/includes.chroot"

echo "[+] Updating apt repositories..."
apt-get update

echo "[+] Installing ARMOR required package suite..."
xargs -a "${SCRIPT_DIR}/config/package-lists/armor.list.chroot" apt-get install -y --no-install-recommends

echo "[+] Deploying ARMOR security configurations..."
cp -r "${CONFIG_DIR}/etc/"* /etc/
cp -r "${CONFIG_DIR}/usr/"* /usr/

echo "[+] Setting executable permissions on ARMOR security engines..."
chmod +x /usr/local/bin/armor-*

echo "[+] Executing chroot hardening hook..."
bash "${SCRIPT_DIR}/config/hooks/live/01-hardening.hook.chroot"

echo "[+] ARMOR security stack successfully provisioned."
