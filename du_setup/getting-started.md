---
layout: default
title: du_setup
nav_order: 3
parent: Home
last_modified_date: 2025-08-29T16:30:00+01:00
---

# Debian & Ubuntu Server Setup & Hardening Script

---

## Table of Contents

1. [Overview & Goals](#overview--goals)
2. [Compatibility & Requirements](#compatibility--requirements)
3. [Feature summary](#feature-summary)
4. [Installation & Usage](#installation--usage)
5. [Detailed feature explanations](#detailed-feature-explanations)
6. [Detailed Feature Walkthrough](#detailed-feature-walkthrough)
7. [Security Features](#security-features)
8. [Logging & Backup System](#logging--backup-system)
9. [Post-Installation Verification](#post-installation-verification)
10. [Advanced Configuration](#advanced-configuration)
11. [Troubleshooting Guide](#troubleshooting-guide)
12. [Best Practices](#best-practices)
13. [FAQ](#faq)
14. [Additional Resources](#additional-resources)

---

## Overview & Goals

The du_setup script automates secure initialization and hardening of fresh Debian and Ubuntu servers, emphasizing idempotence, safety-first changes, and audit-ready logging to produce a production-grade baseline quickly and consistently.
It creates a secure admin account, hardens SSH, enables a restrictive firewall, configures Fail2Ban, time sync, optional kernel hardening, and installs optional components like Docker, Tailscale, and a fully featured backup system with repeatable validations.
Interactive and automation-friendly modes are provided, with a self-update mechanism, rollbacks on SSH connectivity issues, and comprehensive reporting, suitable for both manual and CI-driven workflows.

### Core Principles

- **Idempotent**: Multiple executions won't cause negative effects - the script intelligently detects existing configurations
- **Safety First**: All critical configuration files are backed up before modification with timestamped backups
- **Production Ready**: Designed for real-world deployment scenarios with extensive testing across cloud providers
- **Interactive & Automated**: Operates interactively by default with `--quiet` mode for automation scenarios

### Key Benefits

- **Time Savings**: Reduces server setup time from hours to minutes
- **Consistency**: Ensures standardized security configurations across multiple servers
- **Security**: Implements industry-standard hardening practices
- **Flexibility**: Modular design allows selective feature implementation
- **Reliability**: Extensive error handling and rollback mechanisms

---

## Compatibility & Requirements

### Supported Operating Systems

| OS | Version | Status | Notes |
| :-- | :-- | :-- | :-- |
| Debian | 12 (Bookworm) | ✅ Full support | Extensively tested |
| Debian | 13 (Trixie) | ✅ Full support  | Confirmed in script v0.64 |
| Ubuntu LTS | 20.04 (Focal) | ✅ Full support | Long-term support |
| Ubuntu LTS | 22.04 (Jammy) | ✅ Full support | Long-term support |
| Ubuntu LTS | 24.04 (Noble) | ✅ Full support | Latest LTS |
| Ubuntu | 24.10, 25.04 | ⚠️ Experimental | Not LTS |

### Cloud Provider Testing

The script has been extensively tested on:
- **DigitalOcean** - Droplets
- **Oracle Cloud** - Compute Instances
- **Hetzner** - VPS & Dedicated Servers
- **OVH Cloud** - VPS
- **Netcup** - VPS
- **Local VMs** - VMware, VirtualBox, KVM

### System Requirements

| Requirement | Specification | Notes |
|---|---|---|
| **Privileges** | Root or `sudo` access | Script must run as root |
| **Internet** | Stable connection | For package downloads |
| **Disk Space** | Minimum 2GB free | For swap, backups, and packages |
| **Memory** | 512MB+ RAM | More recommended for Docker |
| **Architecture** | x86_64 (amd64) | Primary target architecture |

### Prerequisites for Optional Features

| Feature | Requirement |
|---|---|
| **Remote Backups** | SSH-accessible server with credentials |
| **Tailscale** | Pre-auth key from Tailscale admin console |
| **Docker** | 2GB+ RAM recommended |
| **Swap Configuration** | Available disk space for swap file |

---

## Feature summary

### Essential security components

| Component | Description | Application |
| :-- | :-- | :-- |
| System checks | Validation of privileges, OS version, filesystem, SSH presence, connectivity | Always applied |
| User management | Creates secure sudo user with key auth, password optional | Always applied |
| SSH hardening | Non-root login, key-only auth, custom port, banner, rollback on failure | Always applied |
| UFW firewall | Default deny incoming, allow outgoing, audited rules | Always applied |
| Fail2Ban | SSH and UFW log-based intrusion prevention | Always applied |
| Time sync | Chrony NTP installation and verification | Always applied |

### Optional enhancements

| Component | Description | Benefit |
| :-- | :-- | :-- |
| Automatic security updates | unattended-upgrades, conservative policies | Continuous patching |
| Kernel hardening | sysctl parameters for network and process security | Attack resistance |
| Docker \& Compose | Runtime and Compose plugin, group membership, hello-world test | Containerization |
| Tailscale VPN | Official installation, keys, exit node, SSH, custom servers | Zero-trust overlay |
| Automated backups | rsync-over-SSH with locking, logs, notifications, cron | Data protection |
| Swap file | Creation, tuning, fstab integration | Stability under pressure |
| Security auditing | Lynis and debsecan (Debian) with reports | Visibility \& compliance |

---

## Installation & Usage

### 1. Download & Prepare

```bash
# Download the script
wget https://raw.githubusercontent.com/buildplan/du_setup/refs/heads/main/du_setup.sh

# Make executable
chmod +x du_setup.sh
```

### 2. Verify Script Integrity (Highly Recommended)

Security is paramount when executing scripts with root privileges. Always verify the script's integrity:

#### Option Automatic Verification
```bash
# Download official checksum
wget https://raw.githubusercontent.com/buildplan/du_setup/refs/heads/main/du_setup.sh.sha256

# Verify (should output: du_setup.sh: OK)
sha256sum -c du_setup.sh.sha256
```

#### Option B: Manual Verification
```bash
# Generate hash
sha256sum du_setup.sh

# Compare with official hash
echo "f72d91643b28939e29b9ffb3b3022dafc8516590cd95286de280a8c9468a1203 du_setup.sh" | sha256sum --check -
```

### 3. Execution Methods

#### Interactive Mode (Recommended)
```bash
# Switch to root (recommended)
sudo su
./du_setup.sh

# Or run with sudo -E (preserves environment variables)
sudo -E ./du_setup.sh
```

#### Automated Mode
```bash
# Quiet mode for automation
sudo -E ./du_setup.sh --quiet
```

### 4. Execution Flow

The script follows this general flow:
1. **System Checks** - Validates environment and prerequisites
2. **Configuration Collection** - Interactive prompts for customization
3. **Package Installation** - Updates system and installs required packages
4. **Security Configuration** - Applies hardening measures
5. **Optional Components** - Docker, Tailscale, backups, etc.
6. **Final Verification** - Tests configuration and generates report


---


## Detailed feature explanations

### System checks

Privilege verification enforces root execution, verifies compatible Debian/Ubuntu versions, confirms /var/log and /etc/shadow writability, and ensures network access to package repositories.
SSH daemon availability is checked and noted for service unit names (ssh.service, sshd.service, ssh.socket) to support OS differences and socket activation behavior.
If unsupported versions are detected, a warning and operator confirmation gate allow opting into best-effort execution with logged caveats.

### Dependency \& update management

The script updates package indexes, installs essentials (curl, sudo, gpg, and SSH components), and performs non-interactive upgrades to ensure a secure baseline before further changes.
All installations use non-interactive flags to prevent stalls in automation and to keep deterministic behavior across runs and environments.
Package installation and upgrade errors are logged and surfaced with early exits to avoid partial or inconsistent states.

### User management

A non-root administrative user is created or reused with validated usernames, optional password setting, and SSH key provisioning or generation, with permissions corrections to ensure secure access.
SSH keys are validated for format, deduplicated in authorized_keys, and generated when absent using Ed25519 with guidance to securely export and store the private key, including IPv4/IPv6 connection examples printed for operator testing.
The user is added to the sudo group with verification, and existing accounts without keys are flagged so keys can be added before disabling password logins.

### System configuration

The script sets and confirms hostname (static and pretty), synchronizes /etc/hosts, prompts and validates timezone settings, and can reconfigure locales interactively, applying new locale settings to the current environment in v0.65+.
A secure backup directory is prepared and populated with pre-change snapshots of key configuration files to allow targeted restoration if needed.
IPv4 and IPv6 public addresses are detected and displayed in v0.66 to aid SSH testing and documentation of access endpoints.

### SSH hardening

SSH is hardened using modular config and service-specific overrides, with a custom port in 1024–65535, disabled root login, disabled password authentication, reduced auth tries, and a legal/security banner.
The script supports Ubuntu’s ssh.socket and ssh.service as well as sshd.service (Debian), generating appropriate systemd overrides or direct configuration edits based on OS and version, including Ubuntu 24.04 handling of Port in sshd_config.
Critically, a mandatory out-of-band SSH login test gate ensures changes finalize only after successful connection; otherwise, a thorough rollback routine restores previous configs and port bindings.

Example hardening (modular file):

```bash
# /etc/ssh/sshd_config.d/99-hardening.conf
PermitRootLogin no
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
PrintMotd no
Banner /etc/issue.net
```


### Firewall configuration (UFW)

UFW is enabled with default deny incoming and allow outgoing, with explicit allow for the chosen SSH port to avoid lockouts and optional allowances for HTTP/HTTPS and Tailscale UDP 41641.
Rules include descriptive comments for audit clarity, and a reminder is issued to align provider-managed edge firewalls with local rules to ensure reachability.
Custom ports can be added with validation that accepts port or port/protocol forms, with rule deduplication and safe insertion logic.

### Intrusion prevention (Fail2Ban)

Fail2Ban is installed and configured to protect SSH on the custom port and to monitor UFW logs for blocked probes, using a custom filter to detect scans and repeated offenses.
To avoid Fail2Ban startup issues when ufw.log is missing, the script creates an empty /var/log/ufw.log before enabling jails and restarting the service (v0.62), improving reliability on fresh systems.
Default jails use bantime 1h, findtime 10m, and maxretry 3, balancing blocking responsiveness with operational continuity while preserving log visibility.

Example SSH jail:

```ini
[sshd]
enabled = true
port = <custom_port>
logpath = %(sshd_log)s
backend = %(sshd_backend)s
bantime = 1h
findtime = 10m
maxretry = 3
```


### Automatic security updates

unattended-upgrades can be enabled with non-interactive configuration, setting conservative patching behavior that focuses on security updates to reduce vulnerability windows.
The script reconfigures via debconf to ensure the service is enabled and emits status guidance for verification and ongoing maintenance.
Operators can opt out in environments requiring strict change windows and manual approvals, with the script reporting the choice.

### Time synchronization (Chrony)

Chrony is installed and enabled for precise NTP synchronization, with status checks (chronyc tracking) included in verification steps to validate time sources and offsets.
Accurate time underpins log integrity, authentication, certificate validation, and clustered operations; the script documents checks and captures status in logs.
Chrony’s systemd integration ensures persistent startup across reboots with minimal operator configuration.

### Kernel security hardening (sysctl)

A comprehensive set of network and system parameters is applied via /etc/sysctl.d/99-du-hardening.conf with immediate activation, including IPv4 spoofing prevention, SYN cookies, redirect ignoring, source-route blocking, martian logging, ptrace and dmesg restrictions, ASLR, and filesystem link protections.
Where IPv6 is in use, redirect and source-route protections are applied similarly to strengthen host posture across dual-stack deployments.
The script checks for idempotence and only updates the sysctl file if contents differ to avoid unnecessary reloads while ensuring persistence across reboots.

### Docker \& Compose (optional)

The script configures Docker’s official repository and installs Docker Engine, the Compose plugin, and dependencies, removing obsolete runtimes to avoid conflicts.
The admin user is added to the docker group, with a hello-world container run to verify installation and permissions, and a note to re-login for group membership to take effect.
Systemd integration is configured so the daemon starts on boot, and daemon options can be extended after installation via standard configuration paths.

### Tailscale VPN (optional)

Tailscale is installed via the official method, enabling tailscaled and supporting pre-auth keys, exit node advertising, SSH over Tailscale, custom login servers (e.g., headscale), and secure handling/sanitization of credentials in logs.
Connectivity is verified with IP assignment checks and service status, with diagnostic guidance and retries to handle transient issues in first-boot environments.
Firewall rules for UDP 41641 are offered, and failure states are recorded with actionable notes for re-authentication and service restart.

### Automated backup system (optional)

The backup system uses rsync-over-SSH with a dedicated root-owned Ed25519 keypair for operations, a configurable set of source directories (defaulting to the new admin’s home), and flexible destination definitions including Hetzner Storage Box on port 23.
A generated /root/run_backup.sh includes dependency checks, flock-based locking, size-based log rotation (~10MB), robust error handling, notifications (ntfy.sh or Discord), stats extraction, and network validation, with a test backup option to confirm end-to-end configuration.
The script writes a customizable exclude file at /root/rsync_exclude.txt, schedules cron (default daily at 03:05), and logs all operations to /var/log/backup_rsync.log, using rsync --delete and --stats by default for efficient synchronization and visibility.

Generated backup script capabilities (excerpt):

```bash
# Locking, logging, and rsync execution (excerpt)
exec 200>"$LOCK_FILE"; flock -n 200 || { echo "Backup already running."; exit 1; }
rsync -avz --delete --stats --exclude-from="$EXCLUDE_FILE" -e "ssh -p $SSH_PORT" $BACKUP_DIRS "${REMOTE_DEST}:${REMOTE_PATH}"
```


### Swap file configuration (optional)

Swap configuration detects existing swap, validates requested sizes against free space, creates a swap file with appropriate permissions, integrates via fstab, and tunes swappiness and vfs_cache_pressure in a sysctl file, skipping inside containerized environments.
Verification steps print swapon --show and free -h to confirm allocation and behavior after activation and across reboots.
Resizing options and safe skips prevent destructive operations on existing swap configurations.

### Security auditing suite (optional)

Lynis audits produce a hardening index and actionable suggestions, saved under /var/log/setup_harden_security_audit_*.log and summarized in the script report for ongoing tracking.
Debian systems can also run debsecan to map installed packages to known CVEs, with severity information included for remediation planning and visibility.
Audit outputs are preserved and integrated into the logging/reporting framework to support compliance, change control, and continuous improvement cycles.

---

## Detailed Feature Walkthrough

### **Setup**
- **Environment**: A fresh VM running **Ubuntu 22.04 LTS** (a supported OS) with:
  - Root privileges (`sudo` or direct root access).
  - Internet connectivity (for package downloads and Tailscale).
  - At least 2GB free disk space (for swap and temporary files).
  - Minimal installation (no prior SSH hardening, UFW, or Fail2Ban configured).
- **Script Version**: v0.52
- **Execution Mode**: Interactive (not `--quiet`), to capture user prompts and verify decision points.

---

### **Walkthrough**

#### **1. Preparation**
- **Download and Permissions**:
  - The README instructs downloading with `wget https://raw.githubusercontent.com/buildplan/du_setup/refs/heads/main/du_setup.sh` and setting `chmod +x du_setup.sh`.
  - Assumed command: `sudo ./du_setup.sh`.
  - The script starts with `#!/bin/bash` and `set -euo pipefail`, ensuring strict error handling.

- **Log File Creation**:
  - The script creates `/var/log/du_setup_$(date +%Y%m%d_%H%M%S).log` (e.g., `/var/log/du_setup_20250630_222800.log`) with `chmod 600`.
  - Backup directory `/root/setup_harden_backup_20250630_222800` is created with `chmod 700`.\c

#### **2. Main Function Execution**

##### **check_dependencies**
- **Logic**: Checks for `curl`, `sudo`, and `gpg`. Installs missing dependencies via `apt-get`.
- **Simulation**:
  - On a fresh Ubuntu 22.04 VM, `sudo` and `curl` are typically present, but `gpg` might be missing in minimal installs.
  - The script runs `apt-get install -y -qq gpg` if needed, which should succeed given internet access.
- **Expected Output**: `✓ All essential dependencies are installed.` (or installs `gpg` if missing).
- **Potential Issues**: None likely, as `apt-get update` and `install` are robust, and internet is assumed available.

##### **check_system**
- **Logic**: Verifies root privileges, OS compatibility (Ubuntu 22.04), internet connectivity, SSH service, and `/var/log` writability.
- **Simulation**:
  - Root check: `id -u` returns 0 (root), passes.
  - OS check: `/etc/os-release` confirms `ID=ubuntu`, `VERSION_ID=22.04`, passes.
  - Container check: No container detected (`/proc/1/cgroup` lacks docker/lxc/kubepod), so `IS_CONTAINER=false`.
  - SSH check: Assumes `openssh-server` is installed (common in Ubuntu server). Detects `ssh.service` or `sshd.service`.
  - Internet check: `curl -s --head https://archive.ubuntu.com` succeeds.
  - `/var/log` and `/etc/shadow` checks: Permissions are correct (640 for `/etc/shadow`, writable `/var/log`).
- **Expected Output**:
  ```
  ✓ Running with root privileges.
  ✓ Compatible OS detected: Ubuntu 22.04 LTS
  ✓ Internet connectivity confirmed.
  ```
- **Potential Issues**: If `openssh-server` is missing, the script installs it later in `install_packages`. No issues expected.

##### **collect_config**
- **Logic**: Prompts for username, hostname, pretty hostname, and SSH port. Validates inputs.
- **Simulation Inputs**:
  - Username: `adminuser` (valid, passes `validate_username`).
  - Hostname: `myserver` (valid, passes `validate_hostname`).
  - Pretty hostname: `My Server` (optional, accepted).
  - SSH port: `2222` (default, passes `validate_port`).
  - Server IP: Detected via `curl -s https://ifconfig.me` (e.g., `192.0.2.1`).
  - Confirmation: User confirms the configuration.
- **Expected Output**:
  ```
  Configuration Summary:
    Username:   adminuser
    Hostname:   myserver
    SSH Port:   2222
    Server IP:  192.0.2.1
  Continue with this configuration? [Y/n]: y
  ```
- **Log Entry**: `Configuration collected: USER=adminuser, HOST=myserver, PORT=2222`
- **Potential Issues**: Invalid inputs (e.g., username with spaces) prompt re-entry, which is robust. No issues expected.

##### **install_packages**
- **Logic**: Updates and upgrades packages, installs essentials (`ufw`, `fail2ban`, `chrony`, `rsync`, etc.).
- **Simulation**:
  - `apt-get update` and `apt-get upgrade -y` run silently.
  - Installs packages like `ufw`, `fail2ban`, `chrony`, `rsync`, `openssh-server`, etc.
  - Assumes sufficient disk space and internet access.
- **Expected Output**: `✓ Essential packages installed.`
- **Potential Issues**: Rare chance of `apt-get` failures due to repository issues, but `set -e` ensures the script exits on error. No issues expected in a fresh VM.

##### **setup_user**
- **Logic**: Creates `adminuser` if it doesn’t exist, sets a password (or skips for key-only), adds to `sudo` group, and configures SSH keys.
- **Simulation**:
  - User `adminuser` doesn’t exist, so `adduser --disabled-password --gecos "" adminuser` runs.
  - Password prompt: User enters `securepassword123` twice, set via `chpasswd`.
  - SSH key prompt: User pastes a valid key (`ssh-ed25519 AAAAC3Nza... user@local`).
  - Key is added to `/home/adminuser/.ssh/authorized_keys` with `chmod 600` and `chown adminuser:adminuser`.
  - Adds `adminuser` to `sudo` group with `usermod -aG sudo adminuser`.
- **Expected Output**:
  ```
  ✓ User 'adminuser' created.
  ✓ SSH public key added.
  ✓ User added to sudo group.
  ✓ Sudo group membership confirmed for 'adminuser'.
  ```
- **Potential Issues**: Password mismatch prompts re-entry. If key is invalid, user is prompted again. Robust validation prevents issues.

##### **configure_system**
- **Logic**: Sets timezone, hostname, and optionally configures locales. Backs up `/etc/hosts`, `/etc/fstab`, `/etc/sysctl.conf`.
- **Simulation**:
  - Timezone: User enters `America/New_York`, validated via `/usr/share/zoneinfo`.
  - Locale configuration: User skips (`dpkg-reconfigure locales` not run).
  - Hostname: Sets `myserver` and pretty name `My Server` via `hostnamectl`.
  - Updates `/etc/hosts` with `127.0.1.1 myserver`.
- **Expected Output**:
  ```
  ✓ Timezone set to America/New_York.
  ✓ Hostname configured: myserver
  ```
- **Potential Issues**: Invalid timezone prompts re-entry. No issues expected.

##### **configure_ssh**
- **Logic**: Hardens SSH by setting a custom port (2222), disabling root login, enforcing key-based auth, and creating `/etc/issue.net`. Includes rollback on failure.
- **Simulation**:
  - Detects `ssh.service` (Ubuntu 22.04).
  - Current port: 22 (default).
  - Backs up `/etc/ssh/sshd_config` to `/root/setup_harden_backup_20250630_222800/sshd_config.backup_*`.
  - Sets port 2222 in `/etc/ssh/sshd_config` (Ubuntu 22.04 uses direct config).
  - Creates `/etc/ssh/sshd_config.d/99-hardening.conf` with:
    ```
    PermitRootLogin no
    PasswordAuthentication no
    PubkeyAuthentication yes
    MaxAuthTries 3
    ClientAliveInterval 300
    X11Forwarding no
    PrintMotd no
    Banner /etc/issue.net
    ```
  - Creates `/etc/issue.net` with a warning banner.
  - Restarts `ssh.service` and verifies port 2222 with `ss -tuln`.
  - User tests SSH: `ssh -p 2222 adminuser@192.0.2.1` (assumed successful).
  - Verifies root login is disabled with `ssh -p 2222 root@localhost` (fails, as expected).
- **Expected Output**:
  ```
  ✓ SSH service restarted on port 2222.
  ✓ Confirmed: Root SSH login is disabled.
  ✓ SSH hardening confirmed and finalized.
  ```
- **Potential Issues**: If the user fails to test SSH on port 2222, the script rolls back to port 22. The `trap` ensures rollback on errors. No issues expected with correct user input.

##### **configure_firewall**
- **Logic**: Configures UFW with deny incoming, allow outgoing, and specific ports (2222/tcp, optional 80/tcp, 443/tcp, 41641/udp).
- **Simulation**:
  - UFW is inactive initially.
  - Sets `ufw default deny incoming`, `ufw default allow outgoing`.
  - Allows `2222/tcp` (SSH).
  - User allows HTTP (80/tcp) and HTTPS (443/tcp), skips Tailscale (41641/udp) and custom ports.
  - Enables UFW with `ufw --force enable`.
- **Expected Output**:
  ```
  ✓ HTTP traffic allowed.
  ✓ HTTPS traffic allowed.
  ✓ Firewall is active.
  Status: active
  To                         Action      From
  --                         ------      ----
  2222/tcp (Custom SSH)     ALLOW       Anywhere
  80/tcp (HTTP)             ALLOW       Anywhere
  443/tcp (HTTPS)           ALLOW       Anywhere
  ```
- **Potential Issues**: If the VPS provider’s firewall blocks port 2222, the user is warned to check. UFW enable failure is caught by `set -e`. No issues expected.

##### **configure_fail2ban**
- **Logic**: Configures Fail2Ban to monitor SSH on port 2222 with `bantime=1h`, `findtime=10m`, `maxretry=3`.
- **Simulation**:
  - Creates `/etc/fail2ban/jail.local` with:
    ```
    [DEFAULT]
    bantime = 1h
    findtime = 10m
    maxretry = 3
    backend = auto
    [sshd]
    enabled = true
    port = 2222
    logpath = %(sshd_log)s
    backend = %(sshd_backend)s
    ```
  - Enables and restarts `fail2ban`.
- **Expected Output**:
  ```
  ✓ Fail2Ban is active and monitoring port(s) 2222.
  Status: sshd
  ```
- **Potential Issues**: Fail2Ban service failure is caught and exits the script. No issues expected.

##### **configure_auto_updates**
- **Logic**: Configures `unattended-upgrades` for automatic security updates.
- **Simulation**:
  - User confirms enabling auto-updates.
  - Sets `unattended-upgrades/enable_auto_updates` to `true` and runs `dpkg-reconfigure`.
- **Expected Output**: `✓ Automatic security updates enabled.`
- **Potential Issues**: Package is already installed via `install_packages`. No issues expected.

##### **configure_time_sync**
- **Logic**: Enables and verifies `chrony` for time synchronization.
- **Simulation**:
  - `systemctl enable --now chrony` runs.
  - `chronyc tracking` confirms synchronization.
- **Expected Output**:
  ```
  ✓ Chrony is active for time synchronization.
  Reference ID    : 192.168.1.1 (time.example.com)
  Stratum         : 2
  ...
  ```
- **Potential Issues**: Chrony failure is caught and exits. No issues expected.

##### **install_docker**
- **Logic**: Installs Docker if user confirms, adds `adminuser` to `docker` group, and runs a `hello-world` test.
- **Simulation**:
  - User confirms Docker installation.
  - Removes old runtimes, adds Docker GPG key and repository, installs `docker-ce`, `docker-ce-cli`, etc.
  - Configures `/etc/docker/daemon.json` with log settings.
  - Adds `adminuser` to `docker` group.
  - Runs `docker run --rm hello-world` as `adminuser`.
- **Expected Output**:
  ```
  ✓ Docker sanity check passed.
  NOTE: 'adminuser' must log out and back in to use Docker without sudo.
  ```
- **Potential Issues**: Docker repository issues are caught by `set -e`. No issues expected with internet access.

##### **install_tailscale**
- **Logic**: Installs Tailscale if confirmed, connects using a pre-auth key, and applies optional flags.
- **Simulation**:
  - User confirms Tailscale installation.
  - Chooses standard Tailscale (option 1).
  - Enters key: `tskey-auth-xyz123`.
  - Skips additional flags ( `--ssh`, `--advertise-exit-node`, etc.).
  - Runs `tailscale up --auth-key=tskey-auth-xyz123 --operator=adminuser`.
  - Verifies connection with `tailscale ip` (e.g., `100.64.0.1`).
- **Expected Output**:
  ```
  ✓ Tailscale connected successfully. Node IPv4 in tailnet: 100.64.0.1
  ```
- **Potential Issues**: Invalid key or network issues are logged to `/tmp/tailscale_status.txt`. Retries (3x) mitigate transient failures.

##### **setup_backup**
- **Logic**: Configures rsync backups over SSH with optional notifications and a test backup.
- **Simulation**:
  - User confirms backup setup.
  - Backup destination: `u12345@u12345.your-storagebox.de`.
  - Port: `23` (Hetzner).
  - Remote path: `/home/backups/`.
  - Hetzner mode: Enabled (uses `-s` for `ssh-copy-id`).
  - Key copy: Manual (user runs `ssh-copy-id -p 23 -i /root/.ssh/id_ed25519.pub -s u12345@u12345.your-storagebox.de`).
  - Creates `/root/.ssh/id_ed25519` if missing.
  - Creates `/root/rsync_exclude.txt` with defaults.
  - Cron schedule: `5 3 * * *` (daily at 3:05 AM).
  - Notifications: Skipped.
  - Test backup: User confirms, creates `/root/test_backup_*`, runs `rsync` to `u12345@u12345.your-storagebox.de:/home/backups/test_backup/`.
- **Expected Output**:
  ```
  ✓ Root SSH key generated at /root/.ssh/id_ed25519
  ACTION REQUIRED: Copy the root SSH key to the backup destination.
  The root user's public key is: ssh-ed25519 AAAAC3Nza... root@myserver
  Run the following command: ssh-copy-id -p "23" -i "/root/.ssh/id_ed25519.pub" -s "u12345@u12345.your-storagebox.de"
  ✓ Rsync exclude file created.
  ✓ Test backup successful! Check /var/log/backup_rsync.log for details.
  ✓ Backup cron job scheduled: 5 3 * * *
  ```
- **Potential Issues**: If the SSH key isn’t copied, the test backup fails, logged to `/var/log/backup_rsync.log`. Manual copy instructions are clear. No issues expected with correct setup.

##### **configure_swap**
- **Logic**: Configures a swap file if confirmed, with default size 2G.
- **Simulation**:
  - User confirms swap creation.
  - Size: `2G`.
  - Disk space check: Assumes >2GB available.
  - Creates `/swapfile` with `fallocate`, `chmod 600`, `mkswap`, `swapon`.
  - Adds `/swapfile none swap sw 0 0` to `/etc/fstab`.
  - Sets `vm.swappiness=10`, `vm.vfs_cache_pressure=50` in `/etc/sysctl.d/99-swap.conf`.
- **Expected Output**:
  ```
  ✓ Swap file created: 2G
  ✓ Swap entry added to /etc/fstab.
  ✓ Swap settings applied to /etc/sysctl.d/99-swap.conf.
  NAME      TYPE  SIZE  USED PRIO
  /swapfile file   2G    0B   -2
  ```
- **Potential Issues**: Insufficient disk space exits the script. No issues expected.

##### **configure_security_audit**
- **Logic**: Runs Lynis and (on Debian) debsecan if confirmed.
- **Simulation**:
  - User confirms audit.
  - Installs `lynis`, runs `lynis audit system --quick`.
  - Skips debsecan (Ubuntu 22.04, not supported).
  - Logs to `/var/log/setup_harden_security_audit_20250630_222800.log`.
  - Extracts hardening index (e.g., `75`).
- **Expected Output**:
  ```
  ✓ Lynis audit completed. Check /var/log/setup_harden_security_audit_20250630_222800.log for details.
  ℹ debsecan is not supported on Ubuntu. Skipping debsecan audit.
  ```
- **Potential Issues**: Lynis failure is logged and doesn’t exit the script. No issues expected.

##### **final_cleanup**
- **Logic**: Runs `apt-get update`, `upgrade`, `autoremove`, `autoclean`, and reloads daemons.
- **Simulation**: All commands succeed.
- **Expected Output**: `✓ Final system update and cleanup complete.`
- **Potential Issues**: Repository issues are logged as warnings, not fatal. No issues expected.

##### **generate_summary**
- **Logic**: Summarizes configuration, checks service status, and provides verification steps.
- **Simulation**:
  - Services (`ssh.service`, `fail2ban`, `chrony`, `ufw`, `docker`, `tailscaled`) are active.
  - Backup is configured, test successful.
  - Tailscale is connected (IP: `100.64.0.1`).
  - Audit ran, hardening index: `75`, debsecan: `Not supported on Ubuntu`.
- **Expected Output**:
  ```
  Setup Complete!
  ✓ Service ssh.service is active.
  ✓ Service fail2ban is active.
  ✓ Service chrony is active.
  ✓ Service ufw is active.
  ✓ Service docker is active.
  ✓ Service tailscaled is active and connected.
  ✓ Security audit performed.
  Configuration Summary:
    Admin User:      adminuser
    Hostname:        myserver
    SSH Port:        2222
    Server IP:       192.0.2.1
    Remote Backup:   Enabled
      - Backup Script: /root/run_backup.sh
      - Destination:   u12345@u12345.your-storagebox.de
      - SSH Port:      23
      - Remote Path:   /home/backups/
      - Cron Schedule: 5 3 * * *
      - Notifications: None
      - Test Status:   Successful
    Tailscale:       Enabled
      - Server:        https://controlplane.tailscale.com
      - Tailscale IPs: 100.64.0.1
      - Flags:         None
    Security Audit:  Performed
      - Audit Log:     /var/log/setup_harden_security_audit_20250630_222800.log
      - Hardening Index: 75
      - Vulnerabilities: Not supported on Ubuntu
    Log File:        /var/log/du_setup_20250630_222800.log
    Backups:         /root/setup_harden_backup_20250630_222800
  Post-Reboot Verification Steps:
    - SSH access:       ssh -p 2222 adminuser@192.0.2.1
    - Firewall rules:   sudo ufw status verbose
    - Time sync:        chronyc tracking
    - Fail2Ban status:  sudo fail2ban-client status sshd
    - Swap status:      sudo swapon --show && free -h
    - Hostname:         hostnamectl
    - Docker status:    docker ps
    - Tailscale status: tailscale status
    - Remote Backup:
        - Verify SSH key: sudo cat /root/.ssh/id_ed25519.pub
        - Copy key if needed: ssh-copy-id -p 23 -s u12345@u12345.your-storagebox.de
        - Test backup:     sudo /root/run_backup.sh
        - Check logs:      sudo less /var/log/backup_rsync.log
    - Security Audit:
        - Check results:   sudo less /var/log/setup_harden_security_audit_20250630_222800.log
  ⚠ ACTION REQUIRED: Ensure the root SSH key (/root/.ssh/id_ed25519.pub) is copied to u12345@u12345.your-storagebox.de.
  ⚠ A reboot is required to apply all changes cleanly.
  Reboot now? [Y/n]: n
  ⚠ Please reboot manually with 'sudo reboot'.
  ```

---

### **Potential Runtime Issues**
- **SSH Lockout**: If the user fails to test SSH on port 2222, the script rolls back to port 22, preventing lockout. The warning to test in a separate terminal is clear.
- **Backup Failure**: If the root SSH key isn’t copied to the backup server, the test backup fails, and logs provide clear troubleshooting steps (e.g., `ssh-copy-id`, `nc -zv`).
- **Tailscale**: Invalid keys or network issues (e.g., UDP 41641 blocked) are caught with retries and logged to `/tmp/tailscale_status.txt`.
- **Disk Space**: Swap creation checks available space, exiting if insufficient. Assumed 2GB available in the VM.
- **Package Installation**: Repository failures are caught by `set -e`, and the script exits cleanly.

---

## Security Features

### Multi-Layer Defense Strategy

The script implements defense in depth through multiple security layers:

#### Layer 1: Access Control
- **SSH Key Authentication**: Eliminates password-based attacks
- **Custom SSH Ports**: Reduces automated scanning exposure
- **User Privilege Separation**: Dedicated admin user with sudo access

#### Layer 2: Network Security
- **Stateful Firewall**: UFW with restrictive default policies
- **Intrusion Prevention**: Fail2Ban with SSH and network monitoring
- **Connection Monitoring**: Real-time attack detection and response

#### Layer 3: System Hardening
- **Kernel Parameters**: Network stack hardening against common attacks
- **Service Minimization**: Only essential services enabled
- **File System Protections**: Hardlink and symlink attack prevention

#### Layer 4: Monitoring & Updates
- **Automated Patching**: Unattended security updates
- **Audit Integration**: Regular security assessments
- **Logging Infrastructure**: Comprehensive activity logging

### Security Best Practices Implementation

#### Password Security
- **Strong Requirements**: Enforced complex password policies
- **Key-Based Auth**: SSH keys preferred over passwords
- **Account Lockout**: Failed attempt protection via Fail2Ban

#### Network Security
- **Port Management**: Systematic approach to service exposure
- **Traffic Filtering**: Application-layer firewall rules
- **Connection Limits**: Rate limiting and connection throttling

#### System Security
- **Privilege Escalation**: Controlled sudo access with logging
- **Process Isolation**: Security boundaries between services
- **File Permissions**: Restrictive default permissions

---

## Logging & Backup System

### Comprehensive Logging Infrastructure

#### Primary Log Files

| Log File | Purpose | Rotation |
|---|---|---|
| `/var/log/du_setup_*.log` | Main script execution log | Manual |
| `/var/log/backup_rsync.log` | Backup operation results | Size-based |
| `/var/log/setup_harden_security_audit_*.log` | Security audit results | Manual |
| `/var/log/du_setup_report_*.txt` | Final configuration summary | Manual |

#### Configuration Backup System

**Backup Location**: `/root/setup_harden_backup_<timestamp>/`

**Protected Files**:
```bash
# SSH Configuration
/etc/ssh/sshd_config
/etc/ssh/sshd_config.d/99-hardening.conf

# System Configuration
/etc/hosts
/etc/fstab
/etc/sysctl.conf

# Security Configuration
/etc/fail2ban/jail.local
/etc/ufw/user.rules
```

#### Log Analysis & Monitoring

**Built-in Analysis**:
- Service status validation
- Configuration verification
- Performance metrics collection
- Error pattern detection

**External Integration**:
- Syslog compatibility
- Centralized logging support
- Monitoring system integration

### Disaster Recovery Capabilities

#### SSH Recovery Procedures
```bash
# Emergency SSH restoration
LATEST_BACKUP=$(ls -td /root/setup_harden_backup_* | head -1)
sudo cp "$LATEST_BACKUP"/sshd_config.backup_* /etc/ssh/sshd_config
sudo rm /etc/ssh/sshd_config.d/99-hardening.conf
sudo systemctl restart ssh
```

#### Configuration Rollback
- **Automated Detection**: Script failures trigger automatic rollback
- **Manual Recovery**: Step-by-step recovery procedures
- **Backup Validation**: Integrity checks on backup files

---

## Post-Installation Verification

### Essential Service Verification

#### SSH Access Testing
```bash
# Test new SSH configuration
ssh -p <custom_port> <username>@<server_ip>

# Verify key-based authentication
ssh -p <custom_port> -i ~/.ssh/id_rsa <username>@<server_ip>
```

#### Security Service Status
```bash
# Firewall status
sudo ufw status verbose

# Fail2Ban jail status
sudo fail2ban-client status
sudo fail2ban-client status sshd
sudo fail2ban-client status ufw-probes

# Time synchronization
chronyc tracking
chronyc sources
```

#### System Configuration Verification
```bash
# Hostname configuration
hostnamectl status

# Swap configuration (if enabled)
sudo swapon --show
free -h

# Kernel hardening parameters
sudo sysctl fs.protected_hardlinks kernel.yama.ptrace_scope net.ipv4.tcp_syncookies
```

### Docker Verification (If Installed)
```bash
# Docker service status
sudo systemctl status docker

# User group membership
groups $USER | grep docker

# Container functionality
docker run --rm hello-world
```

### Tailscale Verification (If Configured)
```bash
# Connection status
tailscale status

# IP assignment
tailscale ip

# Network connectivity
ping <tailscale_peer_ip>

# SSH over Tailscale (if enabled)
tailscale ssh <username>@<tailscale_ip>
```

### Backup System Verification (If Configured)
```bash
# SSH key verification
sudo cat /root/.ssh/id_ed25519.pub

# Manual backup test
sudo /root/run_backup.sh

# Backup log review
sudo less /var/log/backup_rsync.log

# Cron job verification
sudo crontab -l | grep run_backup.sh
```

---

## Advanced Configuration

### Custom SSH Hardening

#### Additional Security Measures
```bash
# Advanced SSH configuration options
Protocol 2
Compression no
TCPKeepAlive no
UseDNS no
GSSAPIAuthentication no
KerberosAuthentication no
StrictModes yes
IgnoreRhosts yes
RhostsRSAAuthentication no
HostbasedAuthentication no
PermitEmptyPasswords no
```

#### Multi-Key Authentication
```bash
# Supporting multiple SSH keys
cat additional_key.pub >> ~/.ssh/authorized_keys

# Key-specific restrictions
from="192.168.1.0/24",command="/usr/bin/rsync" ssh-rsa AAAAB3...
```

### Advanced Firewall Configuration

#### Application-Specific Rules
```bash
# Web server with rate limiting
sudo ufw limit 80/tcp
sudo ufw limit 443/tcp

# Database access restrictions
sudo ufw allow from 192.168.1.0/24 to any port 3306

# Logging configuration
sudo ufw logging on
```

#### IPv6 Configuration
```bash
# Enable IPv6 support
sudo ufw --force enable
echo "IPV6=yes" >> /etc/default/ufw
sudo ufw reload
```

### Custom Backup Configurations

#### Advanced Rsync Options
```bash
# Bandwidth limiting
rsync -avz --bwlimit=1000 --exclude-from="$EXCLUDE_FILE" \
  -e "ssh -p $SSH_PORT" $BACKUP_DIRS "${REMOTE_DEST}:${REMOTE_PATH}"

# Compression and progress
rsync -avzP --exclude-from="$EXCLUDE_FILE" \
  -e "ssh -p $SSH_PORT" $BACKUP_DIRS "${REMOTE_DEST}:${REMOTE_PATH}"
```

#### Notification Customization
```bash
# Custom Discord webhook formatting
send_discord_notification() {
    local status="$1"
    local message="$2"
    local color=$([ "$status" == "SUCCESS" ] && echo "3066993" || echo "15158332")
    
    curl -H "Content-Type: application/json" \
         -d "{\"embeds\":[{\"title\":\"Backup $status\",\"description\":\"$message\",\"color\":$color}]}" \
         "$DISCORD_WEBHOOK"
}
```

### Tailscale Advanced Configuration

#### Custom ACLs and Tags
```bash
# Connect with tags
sudo tailscale up --auth-key=$AUTH_KEY --advertise-tags=tag:server,tag:production

# Custom login server
sudo tailscale up --login-server=https://headscale.example.com --auth-key=$AUTH_KEY
```

#### Exit Node Configuration
```bash
# Enable IP forwarding for exit node
echo 'net.ipv4.ip_forward = 1' >> /etc/sysctl.d/99-tailscale.conf
echo 'net.ipv6.conf.all.forwarding = 1' >> /etc/sysctl.d/99-tailscale.conf
sudo sysctl -p /etc/sysctl.d/99-tailscale.conf

# Advertise as exit node
sudo tailscale up --advertise-exit-node
```

---

## Troubleshooting Guide

### SSH Access Issues

#### Complete SSH Lockout
**Symptoms**: Cannot connect via SSH on any port

**Resolution**:
1. **Console Access**: Use cloud provider's web console
2. **Service Restart**: 
   ```bash
   sudo systemctl restart ssh
   sudo systemctl status ssh
   ```
3. **Configuration Restore**:
   ```bash
   sudo rm /etc/ssh/sshd_config.d/99-hardening.conf
   LATEST_BACKUP=$(ls -td /root/setup_harden_backup_* | head -1)
   sudo cp "$LATEST_BACKUP"/sshd_config.backup_* /etc/ssh/sshd_config
   sudo systemctl restart ssh
   ```

#### Port Connection Issues
**Symptoms**: Connection refused on custom SSH port

**Diagnostic Steps**:
```bash
# Check if SSH is listening on correct port
sudo ss -tuln | grep :2222

# Verify UFW rules
sudo ufw status numbered

# Check cloud provider firewall
# (Provider-specific - check dashboard)
```

**Resolution**:
```bash
# Add UFW rule if missing
sudo ufw allow 2222/tcp

# Restart SSH service
sudo systemctl restart ssh
```

### Backup System Issues

#### SSH Key Authentication Failure
**Symptoms**: Backup fails with "Permission denied (publickey)"

**Diagnostic Steps**:
```bash
# Test SSH connection manually
sudo ssh -p 23 -i /root/.ssh/id_ed25519 user@backup-server.com

# Check key permissions
ls -la /root/.ssh/id_ed25519*

# Verify remote authorized_keys
ssh -p 23 user@backup-server.com "cat ~/.ssh/authorized_keys"
```

**Resolution**:
```bash
# Fix key permissions
sudo chmod 600 /root/.ssh/id_ed25519
sudo chmod 644 /root/.ssh/id_ed25519.pub

# Re-copy public key
sudo ssh-copy-id -p 23 -i /root/.ssh/id_ed25519.pub user@backup-server.com
```

#### Backup Script Execution Issues
**Symptoms**: Cron job not running or failing

**Diagnostic Steps**:
```bash
# Check cron service
sudo systemctl status cron

# Verify crontab entry
sudo crontab -l

# Check backup script permissions
ls -la /root/run_backup.sh

# Review backup logs
sudo tail -f /var/log/backup_rsync.log
```

**Resolution**:
```bash
# Fix script permissions
sudo chmod +x /root/run_backup.sh

# Test manual execution
sudo /root/run_backup.sh

# Verify cron environment
sudo crontab -e
# Add: PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin
```

### Tailscale Connection Issues

#### Service Not Starting
**Symptoms**: `tailscaled` service fails to start

**Diagnostic Steps**:
```bash
# Check service status
sudo systemctl status tailscaled

# Review service logs
sudo journalctl -u tailscaled -f

# Verify installation
which tailscale
tailscale version
```

**Resolution**:
```bash
# Reinstall Tailscale
curl -fsSL https://tailscale.com/install.sh | sh

# Start and enable service
sudo systemctl enable --now tailscaled

# Re-authenticate
sudo tailscale up --auth-key=$YOUR_AUTH_KEY
```

#### Network Connectivity Issues
**Symptoms**: Tailscale installed but no connectivity

**Diagnostic Steps**:
```bash
# Check Tailscale status
tailscale status

# Verify IP assignment
tailscale ip

# Test connectivity
ping 100.64.0.1  # Replace with actual Tailscale IP

# Check firewall rules
sudo ufw status | grep 41641
```

**Resolution**:
```bash
# Allow Tailscale through firewall
sudo ufw allow 41641/udp

# Restart Tailscale
sudo tailscale down
sudo tailscale up --auth-key=$YOUR_AUTH_KEY
```

### Fail2Ban Issues

#### Service Not Blocking IPs
**Symptoms**: Fail2Ban running but not blocking attackers

**Diagnostic Steps**:
```bash
# Check jail status
sudo fail2ban-client status
sudo fail2ban-client status sshd

# Review fail2ban logs
sudo tail -f /var/log/fail2ban.log

# Check jail configuration
sudo fail2ban-client get sshd logpath
```

**Resolution**:
```bash
# Restart Fail2Ban
sudo systemctl restart fail2ban

# Test jail configuration
sudo fail2ban-client reload

# Verify log file exists
sudo touch /var/log/auth.log
sudo systemctl restart fail2ban
```

### Docker Issues

#### Permission Denied Errors
**Symptoms**: User cannot run Docker commands without sudo

**Resolution**:
```bash
# Add user to docker group
sudo usermod -aG docker $USER

# Apply group membership (logout/login required)
newgrp docker

# Verify group membership
groups $USER
```

#### Docker Daemon Issues
**Symptoms**: Docker daemon not running

**Diagnostic Steps**:
```bash
# Check daemon status
sudo systemctl status docker

# Review daemon logs
sudo journalctl -u docker -f
```

**Resolution**:
```bash
# Start Docker daemon
sudo systemctl start docker
sudo systemctl enable docker

# Fix common issues
sudo chmod 666 /var/run/docker.sock  # Temporary fix
# Or restart Docker service (preferred)
sudo systemctl restart docker
```

---

## Best Practices

### Pre-Installation Best Practices

#### Environment Preparation
1. **Fresh Installation**: Always start with a clean OS installation
2. **Backup Strategy**: Ensure you have console/out-of-band access
3. **Network Planning**: Document intended firewall rules and ports
4. **Key Management**: Prepare SSH key pairs before execution

#### Testing Protocol
1. **Staging Environment**: Test script in non-production environment
2. **Provider Compatibility**: Verify with your specific cloud provider
3. **Custom Configurations**: Document any custom requirements

### During Installation Best Practices

#### SSH Security
- **Separate Terminal**: Always test SSH in a separate terminal session
- **Key Verification**: Verify SSH key fingerprints before proceeding
- **Port Documentation**: Record custom SSH port in secure location

#### Configuration Choices
- **Strong Passwords**: Use complex passwords for user accounts
- **Port Selection**: Choose non-standard ports not commonly scanned
- **Service Selection**: Only enable services you actually need

### Post-Installation Best Practices

#### Immediate Actions
1. **Reboot System**: Always reboot after script completion
2. **Verify Access**: Confirm SSH access before closing console sessions
3. **Service Validation**: Check all enabled services are running properly

#### Ongoing Maintenance
1. **Regular Updates**: Monitor automatic updates and supplement as needed
2. **Log Review**: Regularly review security logs and fail2ban reports
3. **Backup Testing**: Periodically test backup restoration procedures
4. **Security Audits**: Run periodic security scans and assessments

#### Security Monitoring
```bash
# Daily monitoring commands
sudo fail2ban-client status
sudo ufw status
sudo systemctl status ssh fail2ban chrony

# Weekly audit checks
sudo lynis audit system --quick
sudo debsecan --suite $(lsb_release -cs)  # Debian only
```

### Long-term Maintenance

#### Update Management
- **Security Patches**: Verify unattended-upgrades is working
- **Manual Updates**: Regularly check for non-security updates
- **Reboot Schedule**: Plan regular maintenance windows for kernel updates

#### Configuration Management
- **Change Documentation**: Document all manual configuration changes
- **Backup Verification**: Regularly test backup restoration
- **Access Review**: Periodically review SSH keys and user accounts

#### Monitoring & Alerting
- **Log Aggregation**: Consider centralized logging solutions
- **Alert Configuration**: Set up monitoring for critical services
- **Performance Tracking**: Monitor resource usage and optimize as needed

---

## FAQ

### General Questions

**Is this script safe to run on production servers?**

The script is designed for production use with extensive safety measures including configuration backups, rollback mechanisms, and comprehensive testing. However, always test in a staging environment first.

**Can I run the script multiple times?**

The script is idempotent. It detects existing configurations and skips already completed steps, making it safe to re-run.

**What happens if something goes wrong during execution?**

The script includes automatic rollback mechanisms, especially for SSH configuration. All original configurations are backed up and can be restored manually if needed.

### Installation & Compatibility

**Which cloud providers are supported?**

The script has been tested on DigitalOcean, Oracle Cloud, Hetzner, OVH Cloud, and Netcup. It should work on any provider offering standard Debian/Ubuntu images.

**Can I use this on existing servers?**

The script is designed for fresh installations. Running on existing servers may conflict with current configurations. Use with extreme caution and extensive testing.

**Does the script work with ARM processors?**

The script primarily targets x86_64 architecture. ARM compatibility depends on package availability and hasn't been extensively tested.

### SSH & Security

**I'm locked out of SSH. What should I do?**

Use your cloud provider's console access to restore the original SSH configuration from the backup directory `/root/setup_harden_backup_*`.

**Can I change the SSH port after running the script?**

Yes, but you'll need to update both the SSH configuration and UFW firewall rules manually.

**How secure is the generated SSH key?**

The script generates Ed25519 keys with strong entropy. However, you should ideally provide your own pre-generated keys.

### Features & Configuration

**Can I skip certain features during installation?**

Most features are optional and presented with confirmation prompts. Essential security features are mandatory.

**How do I modify the backup schedule?**

Edit the cron schedule in `/root/run_backup.sh` and update the crontab with `sudo crontab -e`.

**Can I use custom Docker configurations?**

The script installs Docker with standard configurations. You can customize `/etc/docker/daemon.json` after installation.

### Troubleshooting

**Why is Fail2Ban not blocking attacks?**

Check that the log files exist and Fail2Ban is monitoring the correct SSH port. Review `/var/log/fail2ban.log` for details.

**My backups are failing. How do I troubleshoot?**

Verify SSH key authentication, check network connectivity, and review `/var/log/backup_rsync.log`. Ensure the remote server allows the backup user.

**Tailscale won't connect. What should I check?**

Verify your auth key is valid, check that UDP port 41641 is allowed through firewalls, and ensure the Tailscale service is running.

### Advanced Usage

**Can I integrate this with configuration management tools?**

The script supports `--quiet` mode for automation. You can also extract individual functions for use in Ansible, Puppet, or similar tools.

**How do I customize the kernel hardening parameters?**

Modify `/etc/sysctl.d/99-du-hardening.conf` after installation and reload with `sudo sysctl -p`.

**Can I add custom Fail2Ban jails?**

Add custom jail configurations to `/etc/fail2ban/jail.local` and restart the service.

---

## Additional Resources

### Documentation Links
- **GitHub Repository**: [https://github.com/buildplan/du_setup](https://github.com/buildplan/du_setup)
- **Issue Tracker**: [https://github.com/buildplan/du_setup/issues](https://github.com/buildplan/du_setup/issues)
- **Security Advisories**: Check repository security tab

### External References
- **Ubuntu Server Documentation**: [https://ubuntu.com/server/docs](https://ubuntu.com/server/docs)
- **Debian Administrator's Handbook**: [https://debian-handbook.info/](https://debian-handbook.info/)
- **SSH Hardening Guide**: [https://www.sshaudit.com/hardening_guides.html](https://www.sshaudit.com/hardening_guides.html)
- **UFW Documentation**: [https://help.ubuntu.com/community/UFW](https://help.ubuntu.com/community/UFW)
- **Fail2Ban Manual**: [https://www.fail2ban.org/wiki/index.php/Main_Page](https://www.fail2ban.org/wiki/index.php/Main_Page)

### Community & Support
- **GitHub Discussions**: Use for questions and feature requests
- **Issue Reporting**: Submit detailed bug reports with logs
- **Contributions**: Pull requests welcome for improvements

---

*This documentation is maintained alongside the du_setup script. For the most current version, always refer to the [GitHub](https://github.com/buildplan/du_setup) repository.*

**License**: [MIT License](https://github.com/buildplan/du_setup/blob/main/LICENSE)
**Disclaimer**: This script is provided "as is" without warranty. Use at your own risk and always test in non-production environments first.
