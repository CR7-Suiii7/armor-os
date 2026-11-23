# ARMOR OS — Project Design Document

> **Version:** 1.0 | **Date:** 2026-11-23 | **Author:** Urvish (via design interview)

---

## 1. Project Overview

**ARMOR OS** is a hardened, security-focused operating system distribution based on **Debian 12 (Bookworm)**. It is designed to be a genuine daily-driver secure workstation for privacy-focused power users, security researchers, journalists, activists, penetration testers, and enterprise users who require a provably secure computing environment.

ARMOR OS is not a script that hardens a vanilla Debian install — it is a **fully custom OS distribution** that ships with every security layer pre-configured, pre-integrated, and activated from the moment of installation.

It runs in two deployment modes:
- **Virtual Machine (VM)** — inside Oracle VirtualBox (or compatible hypervisor) on any host OS
- **Bare Metal** — installed directly on physical hardware as the primary operating system

---

## 2. Core Design Philosophy

| Principle | Meaning |
|---|---|
| **Security by Default** | Every setting is locked down at install. The user opts *in* to permitting things, never opts *out* of restrictions. |
| **Zero Trust Boot** | The system will not boot at all without cryptographic proof of an authorized key token. No exceptions. |
| **Irreversible Destruction** | The panic/wipe system guarantees data can never be recovered, reversed, or reverse-engineered once triggered. |
| **Minimal Attack Surface** | Only explicitly whitelisted applications are permitted. Everything else is blocked. |
| **User-Controlled Transparency** | The Security Center GUI shows the user exactly what the system is doing, in real time. |

---

## 3. Visual Identity & Aesthetic

ARMOR OS uses a **military/classified terminal aesthetic** throughout:

- **Color Palette:** Black background + deep red/crimson accents
- **Typography:** Monospace fonts for security-related displays; clean sans-serif for UI chrome
- **Applied to:** Boot splash screen, GRUB menu, LightDM login screen, XFCE desktop theme, Security Center application, panic wipe screen
- **Boot logo:** ARMOR OS shield/wordmark in crimson on black

---

## 4. Desktop Environment

ARMOR OS uses **XFCE** as its desktop environment.

Reasons:
- Lightweight, low memory footprint
- Minimal background processes (smaller attack surface)
- Fully themeable to the ARMOR OS visual identity
- Already proven in the existing VM prototype

XFCE is stripped to the minimum set of components needed. No Bluetooth applets, no file indexers, no cloud sync daemons are included.

---

## 5. System Architecture

### 5.1 Storage Layout (LUKS Full-Disk Encryption)

```
Disk
├── /boot/efi        — EFI partition (unencrypted, UEFI boot)
├── /boot            — Kernel + GRUB (unencrypted)
└── sda3_crypt       — LUKS-encrypted volume containing:
    ├── / (root)
    ├── /home
    └── swap
```

The LUKS passphrase is set by the user during installation. Without it, the disk contents are cryptographically inaccessible.

### 5.2 Boot Flow

```
UEFI Firmware
    ↓
GRUB (loads kernel + initramfs)
    ↓
Initramfs prompts: "Please unlock disk sda3_crypt:"
    ↓  [user enters LUKS passphrase]
systemd starts
    ↓
armor-key-guard.service runs (Before: lightdm.service)
    ↓
  ┌─ Key token present + matches? ─── YES ──→ Boot continues → LightDM → XFCE Desktop
  └─ No / mismatch ─────────────────── NO ───→ CRITICAL ALERT displayed → poweroff -f
```

---

## 6. Security Features

### 6.1 Cryptographic Boot Key Verification *(Already Built)*

Every time the system boots, **before** the desktop or any user session loads, the `armor-key-guard` service executes and performs the following check:

1. Scans for a storage device (virtual ISO disc or USB) labeled `ARMOR_KEY`
2. Mounts the device and reads the Ed25519 private key file from it
3. Derives the public key from the presented private key using `ssh-keygen -y`
4. Compares it against the enrolled public key stored at `/etc/armor/keys/armor_boot.pub`
5. **If they match:** prints a SUCCESS banner and exits with code 0 → boot proceeds
6. **If they don't match (or no token found):** prints the CRITICAL SECURITY ALERT banner, waits 3 seconds, then executes `poweroff -f` — an immediate forced shutdown

**Result:** The system is physically impossible to boot without the correct cryptographic token. Even if someone has the LUKS passphrase, they still cannot reach the desktop without the matching key file.

**Key storage during install:**
- The installer automatically generates a fresh Ed25519 key pair
- The private key is provided to the user as a downloadable file (e.g., `armor_key`) to store on a USB drive or virtual ISO
- The public key is enrolled into `/etc/armor/keys/armor_boot.pub` and `/home/armor/.ssh/authorized_keys`

### 6.2 Full-Disk Encryption (LUKS) *(Already Built)*

The entire operating system partition is encrypted using **LUKS2** (Linux Unified Key Setup). Without the passphrase, the disk contents are random noise. This protects against:
- Physical theft of the machine or disk
- Cold-boot attacks (combined with no swap or encrypted swap)
- Forensic disk imaging

### 6.3 Hardened Firewall — nftables *(Already Built)*

ARMOR OS ships with a **default-deny inbound** firewall policy using `nftables`.

- All inbound traffic is **blocked by default**
- Only explicitly listed ports are allowed (e.g., SSH on a configured port)
- Outbound traffic is filtered to prevent unexpected connections
- Rules are loaded at boot and are non-bypassable by user-space applications

The Security Center provides a GUI view of active rules and open ports.

### 6.4 Key-Only SSH Remote Access *(Already Built)*

Remote SSH login is enforced via `/etc/ssh/sshd_config.d/99-armor-key-only.conf`:

- `PasswordAuthentication no` — passwords are completely disabled
- `PubkeyAuthentication yes` — only the enrolled Ed25519 key works
- `KbdInteractiveAuthentication no` — no interactive challenge-response
- `PermitRootLogin no` — root cannot log in remotely under any circumstances

**Result:** Even if an attacker knows the username and password, they cannot SSH in without the private key file.

### 6.5 Application Whitelisting

ARMOR OS uses a **whitelist-only** application model. Only applications from an explicitly approved curated list may be installed or executed on the system.

- Mechanism: AppArmor profiles + a custom package source restriction that blocks installation of packages not on the whitelist
- The whitelist is managed through the **Security Center** GUI's "App Whitelist Manager" panel
- Users can submit requests to add apps; the whitelist is maintained as a signed manifest
- Any attempt to run a non-whitelisted binary triggers an AppArmor denial and a Security Center alert

### 6.6 Surveillance Protection (Webcam & Microphone)

By default, webcam and microphone hardware is **blocked at the kernel/udev level**:

- A udev rule blacklists the video and audio input device nodes at boot
- No application can access the camera or microphone without explicit user intervention
- To unlock: the user opens the **Security Center**, navigates to "Surveillance Controls," and grants access for the current session only
- Access is revoked automatically on logout or reboot

**Result:** Malware, rogue browser tabs, and remote exploits cannot silently activate the camera or microphone.

### 6.7 Encrypted Communications — Tor Integration

ARMOR OS ships with **Tor** as its default network privacy layer:

- **Tor is optional and user-controlled** — it is not forced on by default
- The user toggles Tor routing on or off from the **Security Center GUI**
- When Tor is **ON**: all network traffic is routed through the Tor network via transparent proxying (`torsocks`/`iptables` redirect rules)
- When Tor is **OFF**: traffic uses the direct connection
- **Tor Browser** is pre-installed for anonymous web browsing regardless of the system-level Tor toggle
- The Security Center shows the current Tor circuit, relay countries, and anonymity status

### 6.8 Automatic Security Auditing

A background security audit service runs **daily** using tools including `lynis`, `chkrootkit`, and custom ARMOR scripts:

- Checks for: open ports, weak file permissions, unauthorized SUID binaries, failed login attempts, rootkits, and configuration drift
- Results are stored in a structured audit log
- Issues are **flagged in the Security Center** in the "Security Audit" panel with severity levels (Info / Warning / Critical)
- The user is not interrupted during normal use; they check the Security Center at their convenience

---

## 7. The Panic / Emergency Data Destruction System

This is ARMOR OS's most critical defensive feature. It is designed for scenarios where the user is under imminent physical threat and must destroy all data before it can be seized.

### 7.1 Trigger

**Keyboard shortcut:** `Shift + Tab + Delete`

This combination is chosen because it is:
- Not accidentally triggerable during normal typing
- Reachable with one hand in an emergency
- Not a standard system shortcut on any OS

### 7.2 Authentication Gate

After the shortcut is pressed, a full-screen overlay appears (black, crimson text) with a single prompt:

```
╔══════════════════════════════════════════════════════╗
║          ARMOR OS EMERGENCY WIPE SYSTEM              ║
║                                                      ║
║  Enter your cryptographic wipe authorization key     ║
║  to initiate secure data destruction.                ║
║                                                      ║
║  Key: [________________________]                     ║
║                                                      ║
║  WARNING: This action is IRREVERSIBLE.               ║
╚══════════════════════════════════════════════════════╝
```

The key prompted here is the **cryptographic wipe authorization key** — a separate secret set by the user during the ARMOR OS installation wizard. It is distinct from:
- The LUKS disk passphrase
- The SSH boot key
- The user account password

If the wrong key is entered, nothing happens and the overlay dismisses. The shortcut must be pressed again to retry.

### 7.3 Destruction Sequence

Upon correct key entry, the destruction sequence begins immediately and cannot be interrupted:

1. **LUKS header destruction** — the LUKS2 header on the encrypted volume is overwritten with random data. Without the header, the LUKS key slots and volume metadata are gone. The encrypted data becomes permanently indecipherable, even with the original passphrase.

2. **Keystore destruction** — `/etc/armor/keys/` is overwritten and deleted, destroying the enrolled boot public key.

3. **Home directory cryptographic shredding** — all files in `/home/` are overwritten with random data multiple times before deletion.

4. **SSH key destruction** — `~/.ssh/` and all key material is shredded.

5. **Swap wiping** — if a swap partition exists, it is overwritten.

6. **Forced immediate poweroff**

**Result:** The disk contains only encrypted random data with no LUKS header to decrypt it, and no key material to reconstruct anything. Recovery is cryptographically impossible.

### 7.4 Final Screen

After destruction completes, before poweroff, the display shows a **full-screen black screen** with the ARMOR OS logo in crimson and the following message:

```
        ▄▄▄  ██▀███   ███▄ ▄███▓ ▒█████   ██▀███
       ▒████▄ ▓██ ▒ ██▒▓██▒▀█▀ ██▒▒██▒  ██▒▓██ ▒ ██▒
       ▒██  ▀█▄▓██ ░▄█ ▒▓██    ▓██░▒██░  ██▒▓██ ░▄█ ▒
       ░██▄▄▄▄██▒██▀▀█▄  ▒██    ▒██ ▒██   ██░▒██▀▀█▄
        ▓█   ▓██░██▓ ▒██▒▒██▒   ░██▒░ ████▓▒░░██▓ ▒██▒
        ▒▒   ▓▒█░ ▒▓ ░▒▓░░ ▒░   ░  ░░ ▒░▒░▒░ ░ ▒▓ ░▒▓░

     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

      ARMOR OS SECURE WIPE COMPLETE.
      ALL DATA HAS BEEN PERMANENTLY DESTROYED.

      This device contains no recoverable information.

     ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

The machine then powers off.

---

## 8. ARMOR Security Center

The **ARMOR Security Center** is the central GUI application for monitoring and controlling all security aspects of the system. It is accessible from the XFCE desktop (taskbar icon or Applications menu).

### 8.1 Panels

| Panel | Function |
|---|---|
| **System Integrity** | Shows boot key status (last verified timestamp), LUKS encryption status, kernel integrity hash, and whether the system configuration has drifted from baseline |
| **Firewall Status** | Live view of active nftables rules, open ports, inbound/outbound connection counts, and the ability to add/remove rules |
| **Active Network Connections** | Real-time list of all active network connections: local port, remote IP, remote port, process name, and bytes transferred |
| **Tor Status** | On/Off toggle for system-wide Tor routing, current Tor circuit visualization (entry → middle → exit relay), anonymity strength indicator |
| **Security Audit** | View results of the most recent daily audit, trigger a manual scan, see flagged issues sorted by severity (Critical / Warning / Info) |
| **App Whitelist Manager** | View the list of approved applications, enable/disable individual apps, see which apps are currently running |
| **Surveillance Controls** | Toggle webcam and microphone access on/off per-session; shows last-access timestamp for each device |
| **Threat Log** | Chronological list of auditd events, failed SSH logins, AppArmor denials, and other security-relevant system events |

### 8.2 Design Language

The Security Center follows the ARMOR OS visual identity: dark background, crimson accents, monospace font for data displays. Status indicators use a simple color system:
- 🟢 **Green** — Secure / Normal
- 🟡 **Amber** — Warning / Needs attention
- 🔴 **Red** — Critical / Immediate action required

---

## 9. Pre-installed Applications

ARMOR OS ships with the following security-focused applications pre-installed and pre-configured:

| Application | Purpose |
|---|---|
| **Tor Browser** | Anonymous web browsing via the Tor network |
| **KeePassXC** | Offline, encrypted local password manager |
| **Wireshark** | Network traffic capture and analysis |
| **nmap** | Network discovery and security scanning |
| **ClamAV** | Open-source antivirus scanning (auto-updated via signed updates) |
| **Signal Desktop** | End-to-end encrypted messaging |
| **Thunderbird** | Email client with OpenPGP encryption support (Enigmail equivalent) |
| **VeraCrypt** | Encrypted container volumes for sensitive files |
| **OnionShare** | Anonymous file sharing and web hosting via Tor hidden services |
| **BleachBit** | Secure file shredding and disk cleaning |

All pre-installed applications are on the application whitelist by default.

---

## 10. Installer

The ARMOR OS installer is a **custom graphical wizard** that runs from a bootable ISO.

### 10.1 Installer Flow

```
1. Boot from ARMOR OS ISO
2. ARMOR OS branded welcome screen (black + crimson)
3. Language & keyboard layout selection
4. Disk selection & partitioning
   └── Automatic: LUKS-encrypted layout (EFI + /boot + encrypted root)
   └── LUKS passphrase creation (must meet complexity requirements)
5. User account creation (username + password)
6. Set Cryptographic Wipe Authorization Key (for panic system)
7. Automatic Ed25519 boot key pair generation
   └── Public key enrolled into /etc/armor/keys/armor_boot.pub
   └── Private key presented for download: "Save this file. Without it, 
       you cannot boot ARMOR OS."
8. Base system installation + package installation
9. GRUB installation
10. First-boot configuration (timezone, network)
11. Installation complete — "Remove installation media and reboot"
```

### 10.2 Key Warning Screen

After key pair generation, the installer shows an explicit, prominent warning screen:

> ⚠️ **YOUR BOOT KEY HAS BEEN GENERATED**
>
> Save the file `armor_key` to a USB drive or secure location RIGHT NOW.
>
> This key is required EVERY TIME you start ARMOR OS. If you lose it, the system **will not boot** and your data **cannot be recovered**.
>
> ARMOR OS does not store a backup of this key.

---

## 11. Update System

ARMOR OS connects to a **dedicated ARMOR OS update server** to receive signed security patches automatically.

### 11.1 Update Architecture

- The update server hosts a signed APT repository with ARMOR-specific packages and security configurations
- All updates are **signed with the ARMOR OS project GPG key** — the system rejects any unsigned or invalidly signed packages
- Security-critical updates (kernel, LUKS tooling, SSH, Tor) are applied automatically and silently
- Application and feature updates require user approval via the Security Center "Update Status" notification
- The update system itself is part of the application whitelist and cannot be disabled by user-space processes

### 11.2 Update Verification

Before applying any update:
1. Package signature is verified against the ARMOR OS GPG public key
2. Package hash is verified against the signed manifest
3. If either check fails, the update is rejected and an alert is raised in the Security Center

---

## 12. What Is Already Built (Current State)

The following components from this project have been implemented and verified in the current VirtualBox prototype:

| Component | Status | Location |
|---|---|---|
| Debian 12 base VM | ✅ Done | `ARMOR-Workstation.vdi` |
| LUKS full-disk encryption | ✅ Done | `sda3_crypt` |
| Ed25519 key pair | ✅ Done | `c:\Users\Urvish\OS\armor-os\keys\armor_key` |
| Boot key guard service | ✅ Done | `/etc/systemd/system/armor-key-guard.service` |
| Boot verification script | ✅ Done | `/usr/local/bin/armor-boot-key-check` |
| Key-only SSH | ✅ Done | `/etc/ssh/sshd_config.d/99-armor-key-only.conf` |
| nftables firewall | ✅ Done | Active, default-deny |
| Virtual key token ISO | ✅ Done | `armor-key-token.iso` (ARMOR_KEY label) |
| Windows host helper scripts | ✅ Done | `Attach-ArmorKey.ps1`, `Login-SSH.ps1`, etc. |
| Security hardening report | ✅ Done | `ARMOR_OS_Hardening_Report.html` |

---

## 13. What Remains To Be Built

| Component | Priority |
|---|---|
| Custom ARMOR OS branding (boot splash, login, desktop theme) | High |
| ARMOR Security Center application | High |
| Panic wipe system (`Shift+Tab+Delete` → auth → destruction) | High |
| Tor integration + toggle in Security Center | High |
| Surveillance protection (webcam/mic udev block + Security Center control) | High |
| Application whitelisting (AppArmor + package restrictions) | Medium |
| Automatic daily security audit service | Medium |
| Custom graphical installer wizard | Medium |
| ARMOR OS update server + signed repository | Medium |
| Pre-installed app bundle (Tor Browser, KeePassXC, Signal, etc.) | Medium |
| Panic wipe screen (crimson ARMOR OS "DATA DESTROYED" display) | Medium |

---

## 14. Summary

ARMOR OS is a complete, opinionated secure operating system. It treats security not as a setting to be configured by the user after install, but as an **architectural constraint** baked into every layer: the boot process, the disk layout, the network stack, the application model, and the emergency response system.

Its defining features — cryptographic boot gating, full-disk encryption, default-deny networking, surveillance blocking, app whitelisting, and irreversible panic destruction — work together to create a system where:

- **An attacker with physical access** cannot boot or read the disk.
- **An attacker with network access** cannot authenticate or pivot.
- **A compromised application** cannot silently surveil or exfiltrate.
- **A seized device** can be rendered permanently unreadable in seconds.
