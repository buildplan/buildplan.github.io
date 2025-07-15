---
layout: default
title: du_setup
nav_order: 3
parent: Home
last_modified_date: 2025-07-15T12:30:00+01:00
---

# Debian & Ubuntu Server Setup & Hardening Script

This document provides a guide for the `du_setup` script, a tool for the initial setup and security hardening of Debian and Ubuntu servers. It is designed to be more detailed than the standard README, offering in-depth explanations of the script's functions and processes.

### **Overview**

The `du_setup` script is an idempotent and automated tool for establishing a secure baseline on a fresh Debian or Ubuntu server installation. It is designed to be safe for production environments, running interactively to guide you through key decisions while automating a wide array of essential security and configuration tasks.

**Core Principles:**

  * **Idempotent:** Running the script multiple times will not cause negative side effects. It checks for existing configurations and skips steps that have already been completed.
  * **Safety First:** The script backs up all critical configuration files before making any modifications. These backups are stored in a timestamped directory in `/root/`.
  * **Interactive and Automated:** The script operates interactively by default but also supports a `--quiet` mode for fully automated provisioning.

### **Compatibility**

The script is officially compatible with the following operating systems:

  * **Debian:** 12
  * **Ubuntu LTS:** 22.04, 24.04
  * **Ubuntu (Experimental):** 24.10, 25.04

It has been tested on local VMs and various cloud providers, including DigitalOcean, Oracle Cloud, Hetzner, OVH Cloud and Netcup.

-----

### **Getting Started**

#### **1. Prerequisites**

Before running the script, ensure you have the following:

  * A fresh installation of a compatible OS.
  * Root or `sudo` privileges. The script must be run as root.
  * Internet access for downloading packages.
  * A minimum of 2GB of free disk space, which is required for tasks like swap file creation.
  * (For Remote Backups) An SSH-accessible server, such as a Hetzner Storage Box.
  * (For Tailscale) A pre-authentication key from your Tailscale admin console.

#### **2. Download and Prepare**

First, download the script and make it executable.

```bash
wget https://raw.githubusercontent.com/buildplan/du_setup/refs/heads/main/du_setup.sh
chmod +x du_setup.sh
```

#### **3. Verify Script Integrity (Recommended)**

To ensure the script you downloaded has not been tampered with, you should verify its SHA256 checksum. This is a critical security step.

**Option A: Automatic Check**

This method downloads the official checksum and compares it automatically.

```bash
# Download the official checksum file
wget https://raw.githubusercontent.com/buildplan/du_setup/refs/heads/main/du_setup.sh.sha256

# Run the check. The output should be: du_setup.sh: OK
sha256sum -c du_setup.sh.sha256
```

**Option B: Manual Check**

Generate the hash of your local script and compare it to the official one.

```bash
# Generate the hash of your downloaded script
sha256sum du_setup.sh
```

Compare the resulting hash with the one published in the official `README.md` file. They must match exactly.

#### **4. Execution**

Run the script with root privileges. It is recommended to use `sudo -E` to preserve environment variables.

**Interactive Mode (Recommended):**

```bash
sudo -E ./du_setup.sh
```

**Quiet Mode (For Automation):**

For automated provisioning, you can use the `--quiet` flag. This will suppress non-critical output and use default values where possible.

```bash
sudo -E ./du_setup.sh --quiet
```

-----

### **Core Features & Functionality**

The script is composed of several modules that handle specific aspects of server setup and hardening.

#### **System Checks and Preparation**

  * **Privilege Check:** The script first verifies it's being run as root (`uid=0`). If not, it will exit with an error message.
  * **OS Compatibility:** It reads `/etc/os-release` to ensure the OS is a compatible version of Debian or Ubuntu.
  * **Dependency Installation:** It checks for essential tools like `curl`, `sudo`, and `gpg` and installs any that are missing.
  * **Internet Connectivity:** It confirms internet access by attempting to connect to the official Debian or Ubuntu package archives.

#### **Secure User Management**

This module creates a new administrative user to discourage the use of the root account for daily tasks.

  * **New `sudo` User:** The script prompts for a new username. It then creates this user, sets a password (or can skip password creation for key-only access), and adds them to the `sudo` group.
  * **SSH Key Configuration:** You are prompted to add an SSH public key for the new user. This is the recommended way to secure SSH access. If you don't provide a key, the script will generate a new SSH key pair (`ed25519`) and display the private key for you to save. **This is your only chance to save the generated private key.**
  * **Disabling Root SSH Access:** As part of SSH hardening, direct SSH login for the `root` user is disabled.

#### **SSH Hardening**

This is a critical step to protect the server from unauthorized access.

  * **Custom SSH Port:** You will be prompted to choose a custom SSH port (default: `2222`). Using a non-standard port helps reduce exposure to automated bots scanning port 22.
  * **Enforced Key-Based Authentication:** The script modifies the SSH daemon configuration to disable password-based authentication (`PasswordAuthentication no`) and permit only public key authentication (`PubkeyAuthentication yes`).
  * **Configuration & Rollback:** The script creates a dedicated hardening configuration file at `/etc/ssh/sshd_config.d/99-hardening.conf`. Before finalizing changes, it prompts you to test the new SSH connection from a separate terminal. If you cannot connect, the script has a built-in function (`rollback_ssh_changes`) to restore the original SSH configuration, preventing you from being locked out.
  * **Security Banner:** It creates a banner at `/etc/issue.net` that warns users about unauthorized access.

#### **Firewall Configuration (UFW)**

The script configures the Uncomplicated Firewall (UFW) to control network traffic.

  * **Default Policies:** It sets the default policy to deny all incoming traffic and allow all outgoing traffic.
  * **Allowed Ports:** It automatically allows the custom SSH port you selected. You are then interactively prompted to allow other common ports, such as HTTP (80), HTTPS (443), and Tailscale (UDP 41641). You can also add a list of your own custom ports.
  * **Activation:** The firewall is enabled and its status is displayed for verification.

#### **Intrusion Prevention (Fail2Ban)**

Fail2Ban is installed to automatically block IP addresses that exhibit malicious behavior.

  * **SSH Protection:** A `jail` is configured to monitor the custom SSH port. After a set number of failed login attempts (`maxretry = 5`), the offending IP is banned for a specified time (`bantime = 1d`).
  * **UFW Log Monitoring:** The script adds a custom Fail2Ban filter and jail named `ufw-probes`. This monitors `/var/log/ufw.log` for blocked connection attempts (e.g., from port scans) and bans the source IPs, providing proactive protection against scanners.
  * **Configuration:** All Fail2Ban settings are written to `/etc/fail2ban/jail.local` to ensure they persist across updates.

#### **Automated Security Updates**

To ensure the server remains secure over time, the script configures `unattended-upgrades`. This service will automatically download and install security-related package updates in the background.

#### **System Stability**

  * **Time Synchronization:** The `chrony` service is installed and enabled to keep the system's time accurate by synchronizing with NTP servers.
  * **Swap File:** For systems with low RAM, the script can create a swap file. You are prompted for the desired size (e.g., 2G). It also tunes system `swappiness` and `vfs_cache_pressure` settings for better performance on servers.

#### **Remote `rsync` Backups**

The script can configure automated daily backups to any remote server accessible via SSH.

  * **SSH Key for Root:** It generates a dedicated SSH key for the `root` user, stored at `/root/.ssh/id_ed25519`, which will be used for the backup job.
  * **Destination & Scheduling:** You are prompted for the remote server's details (user, host, port) and the desired cron schedule for the backup.
  * **SSH Key Transfer:** You can choose to copy the SSH key automatically using `sshpass` (less secure, requires a password) or manually via `ssh-copy-id` (recommended). For Hetzner Storage Boxes, it correctly uses the `-s` flag and port 23.
  * **Backup Script:** A self-contained backup script is created at `/root/run_backup.sh`. This script handles the `rsync` process, logging, and notifications.
  * **Notifications:** You can optionally configure notifications for backup success or failure via **ntfy** or a **Discord webhook**.
  * **Exclusions:** A default exclude file is created at `/root/rsync_exclude.txt` to prevent backing up unnecessary files like caches and logs. You can add your own exclusions.

#### **Backup Testing**

After configuring remote backups, the script offers to run a test backup. It creates a temporary file and attempts to `rsync` it to the destination, verifying that the SSH key, path, and permissions are all correct before the first scheduled backup runs. The result is logged to `/var/log/backup_rsync.log`.

#### **Tailscale VPN**

The script can install and configure Tailscale.

  * **Installation:** It uses the official `install.sh` script from Tailscale.
  * **Connection:** You are prompted to provide a pre-auth key to connect the node to your tailnet. It supports both the standard Tailscale service and custom servers (like Headscale). The new node is associated with the admin user you created (`--operator=$USERNAME`).
  * **Optional Flags:** You can enable additional features like `--ssh`, `--advertise-exit-node`, `--accept-dns`, and `--accept-routes` through an interactive menu.

#### **Security Auditing**

For a deeper security analysis, the script can run two auditing tools.

  * **Lynis:** If selected, `lynis` is installed and runs a system audit. The results, including the final "Hardening Index," are saved to a log file for later review.
  * **debsecan:** On Debian systems, you can also run `debsecan` to check for known vulnerabilities (CVEs) in the installed packages.

-----

### **Logs and Configuration Backups**

  * **Main Log File:** All actions performed by the script are logged to `/var/log/du_setup_*.log`.
  * **Configuration Backups:** Before any modifications are made, original configuration files are backed up into `/root/setup_harden_backup_*`.
  * **Backup Log:** The output of all remote backup jobs (both test and scheduled) is logged to `/var/log/backup_rsync.log`.
  * **Audit Log:** The results from Lynis and debsecan are stored in `/var/log/setup_harden_security_audit_*.log`.

-----

### **Post-Installation and Verification**

After the script finishes, a reboot is required to ensure all changes are applied. You should then verify that all services are working correctly. A detailed list of verification commands is provided in the final summary output.

-----

### **Troubleshooting**

The `README.md` provides detailed, step-by-step instructions for recovering from common issues.

  * **SSH Lockout:** Use your cloud provider's web console to restore the original SSH configuration from the backup directory.
  * **Backup Issues:** Check logs, verify the root SSH key was copied correctly, test the connection manually, and check the cron job syntax.
  * **Tailscale Issues:** Verify the service status, check for a valid IP address, re-run the `tailscale up` command, and check for network blocks (UDP 41641).
