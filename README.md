# ARMOR OS: Hardened Company-Managed Linux Workstation

ARMOR is a defense-in-depth, hardened enterprise Linux distribution running inside Oracle VirtualBox with UEFI and virtual TPM 2.0.

## Hardware & VM Architecture
- **Hypervisor:** Oracle VirtualBox 7.x
- **VM Name:** `ARMOR-Workstation`
- **Firmware:** UEFI with Virtual TPM 2.0
- **Compute:** 4096 MB RAM, 2 vCPUs
- **Audio:** Intel HD Audio (`hda`) with hardware microphone capture restricted via WirePlumber policies
- **Peripherals:** USB 3.0 (xHCI) enabled for YubiKey/Smartcard hardware token passthrough
- **Storage:** 30 GB Virtual SATA Disk (LUKS encrypted) + Virtual Optical SATA Drive

## Security Controls
1. **Key-Based PAM Authentication:** No password logins allowed. All authentications require Ed25519 cryptographic challenge-response validation against `/etc/armor/keys/allowed_signers`.
2. **Strict Role Separation:**
   - **Admin (`armor`):** Administrative access, `sudo` rights for security tools, user provisioning (`armor-usermgmt`).
   - **Restricted Users:** Office kiosk environment (Firefox ESR, LibreOffice, Thunderbird). No terminal emulators, no compilers, no sudo, no USB storage mounting (`udev` & `polkit` blocked).
3. **Enterprise Hardened Firefox ESR:**
   - Private browsing disabled.
   - Managed extension allowlist (uBlock Origin forced).
   - Domain whitelist policy.
   - Sandboxed downloads restricted to `~/Downloads/sandboxed/`.
4. **Defensive Lockdown & Breach Engine:**
   - Automatically triggered on 3 failed authentications, AIDE integrity check failure, or unauthorized privilege escalation.
   - User keys revoked instantly and archived into quarantine.
   - Emergency network killswitch drops all incoming and outgoing packets via `nftables`.
   - Desktop terminated; console displays incident banner with unique `Incident ID`.
   - Requires administrative unlock (`armor-admin-unlock`) using the master admin hardware key.
5. **Tamper-Evident Logging:**
   - Cryptographic sequential SHA-256 hash chaining stored at `/var/log/armor/incident.log` with Linux append-only (`chattr +a`) protection.

## Launching the VM
Run the following PowerShell command on your Windows 11 host:
```powershell
powershell -ExecutionPolicy Bypass -File .\attach-iso-and-start.ps1
```
