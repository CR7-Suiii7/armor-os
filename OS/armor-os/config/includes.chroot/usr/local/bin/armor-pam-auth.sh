#!/usr/bin/env bash
# ==============================================================================
# ARMOR Key-Based PAM Authentication Engine (No Password Login Allowed)
# ==============================================================================
set -euo pipefail

TARGET_USER="${PAM_USER:-${1:-}}"
FAIL_COUNT_FILE="/run/armor/fail_count_${TARGET_USER}"
KEY_STORE="/etc/armor/keys"
SIGNERS_FILE="${KEY_STORE}/allowed_signers"
NONCE_DIR="/run/armor/challenges"
TOKEN_MOUNT="/media/armor-token"
FAIL_LIMIT=3

mkdir -p "${NONCE_DIR}" /run/armor
chmod 700 /run/armor

# Check system lock status first
if [ -f "/etc/armor/lockout.active" ]; then
    echo "[!] ARMOR SYSTEM IS LOCKED DUE TO SECURITY BREACH." >&2
    exit 1
fi

if [ -z "${TARGET_USER}" ]; then
    exit 1
fi

# Ensure user public key is in allowed_signers
if [ ! -f "${SIGNERS_FILE}" ] || ! grep -q "^${TARGET_USER} " "${SIGNERS_FILE}"; then
    echo "[ERROR] User '${TARGET_USER}' is not enrolled in ARMOR key store." >&2
    exit 1
fi

# Locate Private Key: Check Virtual TPM, YubiKey/FIDO2, or USB Token Key Store
USER_PRIV_KEY=""
if [ -f "${TOKEN_MOUNT}/${TARGET_USER}.id_ed25519" ]; then
    USER_PRIV_KEY="${TOKEN_MOUNT}/${TARGET_USER}.id_ed25519"
elif [ -f "/var/lib/armor/tpm_keys/${TARGET_USER}.key" ]; then
    USER_PRIV_KEY="/var/lib/armor/tpm_keys/${TARGET_USER}.key"
fi

if [ -z "${USER_PRIV_KEY}" ] || [ ! -r "${USER_PRIV_KEY}" ]; then
    echo "[AUTH-FAILED] No cryptographic token or hardware key detected for user ${TARGET_USER}." >&2
    # Increment failure counter
    COUNT=$(cat "${FAIL_COUNT_FILE}" 2>/dev/null || echo 0)
    COUNT=$((COUNT + 1))
    echo "${COUNT}" > "${FAIL_COUNT_FILE}"
    
    if [ "${COUNT}" -ge "${FAIL_LIMIT}" ]; then
        /usr/local/bin/armor-breach-handler --trigger "EXCESSIVE_FAILED_AUTH" --user "${TARGET_USER}"
    fi
    exit 1
fi

# Generate cryptographically secure random nonce
NONCE_FILE="${NONCE_DIR}/${TARGET_USER}_$(date +%s%N).nonce"
head -c 64 /dev/urandom | base64 > "${NONCE_FILE}"
SIG_FILE="${NONCE_FILE}.sig"

# Perform challenge signing using Ed25519 private key
if ! ssh-keygen -Y sign -f "${USER_PRIV_KEY}" -n "armor-login" "${NONCE_FILE}" >/dev/null 2>&1; then
    rm -f "${NONCE_FILE}" "${SIG_FILE}"
    echo "[AUTH-FAILED] Hardware key signature computation failed." >&2
    exit 1
fi

# Verify signature against root-owned allowed_signers store
if ssh-keygen -Y verify -f "${SIGNERS_FILE}" -I "${TARGET_USER}" -n "armor-login" -s "${SIG_FILE}" < "${NONCE_FILE}" >/dev/null 2>&1; then
    # Auth success: reset failure counter and clean challenge artifacts
    rm -f "${FAIL_COUNT_FILE}" "${NONCE_FILE}" "${SIG_FILE}"
    /usr/local/bin/armor-hashlog "AUTH_SUCCESS" "User ${TARGET_USER} authenticated successfully via hardware key."
    exit 0
else
    rm -f "${NONCE_FILE}" "${SIG_FILE}"
    echo "[AUTH-FAILED] Cryptographic signature verification failed." >&2
    
    COUNT=$(cat "${FAIL_COUNT_FILE}" 2>/dev/null || echo 0)
    COUNT=$((COUNT + 1))
    echo "${COUNT}" > "${FAIL_COUNT_FILE}"
    
    if [ "${COUNT}" -ge "${FAIL_LIMIT}" ]; then
        /usr/local/bin/armor-breach-handler --trigger "EXCESSIVE_FAILED_AUTH" --user "${TARGET_USER}"
    fi
    exit 1
fi
