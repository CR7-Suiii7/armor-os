#!/usr/bin/env bash
# ==============================================================================
# ARMOR Security Verification & Attack Simulation Suite
# Run inside ARMOR VM to validate security controls and breach response
# ==============================================================================
set -euo pipefail

echo "======================================================================"
echo "          ARMOR TEST PLAN & ATTACK SIMULATION SUITE                   "
echo "======================================================================"

test_auth_lockdown() {
    echo "[TEST 1] Simulating 3 consecutive invalid authentication attempts..."
    for i in 1 2 3; do
        echo " -> Attempt $i with invalid token..."
        PAM_USER="alice" /usr/local/bin/armor-pam-auth.sh || true
    done

    echo "[+] Checking if lockdown was triggered..."
    if [ -f "/etc/armor/lockout.active" ]; then
        echo "[PASS] System lockout active. Incident details:"
        cat /etc/armor/lockout.active
    else
        echo "[FAIL] Lockout flag was not created!"
        exit 1
    fi

    echo "[+] Checking if network is isolated (nftables)..."
    if nft list ruleset | grep -q "table inet lockdown"; then
        echo "[PASS] Emergency network killswitch active."
    else
        echo "[FAIL] Network killswitch not found in nftables!"
        exit 1
    fi
}

test_admin_recovery() {
    echo -e "\n[TEST 2] Testing Admin Recovery Unlock..."
    # Generate mock admin keys if not present for test harness
    mkdir -p /tmp/armor_test_admin /etc/armor/admin
    if [ ! -f "/tmp/armor_test_admin/admin.key" ]; then
        ssh-keygen -t ed25519 -N "" -f /tmp/armor_test_admin/admin.key -C "admin-test" >/dev/null
        echo "armor $(cat /tmp/armor_test_admin/admin.key.pub)" > /etc/armor/admin/admin_signers
    fi

    echo "/tmp/armor_test_admin/admin.key" | /usr/local/bin/armor-admin-unlock

    if [ ! -f "/etc/armor/lockout.active" ]; then
        echo "[PASS] Lockout cleared successfully by Admin."
    else
        echo "[FAIL] Lockout flag persists after admin unlock!"
        exit 1
    fi
}

test_user_restrictions() {
    echo -e "\n[TEST 3] Validating Office User Isolation Controls..."
    echo "[+] Checking Terminal binary permissions..."
    ls -l /usr/bin/xfce4-terminal /usr/bin/x-terminal-emulator || true
    echo "[+] Checking USB mass storage modprobe blacklist..."
    modprobe usb-storage 2>&1 || true
    echo "[+] Checking Firefox enterprise policies..."
    cat /etc/firefox-esr/policies/policies.json | grep -E "DisablePrivateBrowsing|WebsiteFilter"
}

case "${1:-all}" in
    attack)
        test_auth_lockdown
        ;;
    recover)
        test_admin_recovery
        ;;
    verify)
        test_user_restrictions
        ;;
    all)
        test_auth_lockdown
        test_admin_recovery
        test_user_restrictions
        ;;
esac

echo -e "\n[+] Test execution completed."
