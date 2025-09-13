---
layout: default
title: Restic Backup Script
nav_order: 12
parent: Home
last_modified_date: 2025-09-13T20:58:00+01:00
---

# Encrypted, Automated Backups with Restic

This guide provides a comprehensive walkthrough for installing, configuring, and operating automated backup system on Linux system using Restic. It is built around a shell script that handles encryption, retention policies, logging, notifications, and reliable unattended operation.

This document covers first-time setup, daily use, data restoration, repository maintenance, and troubleshooting.

-----

## Overview & Features

This backup solution provides the following key features:

  * **Secure Backups:** Employs Restic for client-side encryption, ensuring data is secure before it leaves server. It also supports deduplication and compression to save storage space.
  * **Centralized Configuration:** All settings—sources, retention, performance, notifications, and exclusions—are managed in a single, well-commented `restic-backup.conf` file.
  * **Automation Script:** The `restic-backup.sh` script includes:
      * **Pre-flight Checks:** Validates dependencies, configuration, and repository connectivity before every run.
      * **Concurrency Control:** Uses `flock` to prevent multiple backup instances from running simultaneously.
      * **Safe Operations:** Features an interactive restore wizard with a dry-run mode, integrity checks, and stale lock handling.
      * **Automated Maintenance:** Manages log rotation and applies sophisticated retention policies (`--forget` and `--prune`).
  * **Comprehensive Monitoring:** Integrates with **ntfy** and **Discord** for detailed success, warning, and failure notifications, and supports **Healthchecks.io** for "dead man's switch" monitoring.

-----

## System Requirements

  * A modern Linux distribution with Bash and essential command-line utilities.
  * A remote SFTP server (e.g., Hetzner Storage Box) or another Restic-supported backend.
  * The required software packages, detailed in the installation section.

-----

## File Structure

It is a good idean to set restrictive permissions to protect configuration and credentials.

```
/root/scripts/backup/
├── restic-backup.sh      # The main executable script (permissions: 700)
├── restic-backup.conf    # Settings and credentials (permissions: 600)
└── restic-excludes.txt   # Patterns to exclude from backups (optional)
```

-----

## 1. Installation

### Step 1: Install Prerequisites

The script relies on several common packages. Install them with system's package manager.

**On Debian/Ubuntu:**

```sh
sudo apt-get update && sudo apt-get install -y restic jq gnupg curl bzip2 util-linux coreutils less
```

**On CentOS/RHEL/Fedora:**

```sh
sudo dnf install -y restic jq gnupg curl bzip2 util-linux coreutils less
```

| Package        | Purpose                                                                                   |
| :------------- | :---------------------------------------------------------------------------------------- |
| **`restic`** | The core backup engine. The script can also auto-install/update this.                       |
| **`jq`** | Required for the `--diff` command to parse JSON output.                                         |
| **`curl`** | Used for sending notifications and checking for updates.                                      |
| **`bzip2`** | Required for decompressing the Restic binary during auto-updates.                            |
| **`gnupg`** | Provides `gpg` to verify PGP signatures during secure auto-updates.                          |
| **`util-linux`** | Provides `flock` for concurrency control and `ionice` for I/O scheduling.               |
| **`coreutils`** | Provides essential commands (`date`, `grep`, `mktemp`, etc.).                            |
| **`less`** | Used for navigating file lists in the interactive `--restore` mode.                           |

### Step 2: Download and Prepare Files

Create the directory and download the script files.

```sh
# Create the directory and navigate into it
mkdir -p /root/scripts/backup && cd /root/scripts/backup

# Download the script, config template, and excludes file
curl -LO https://github.com/buildplan/restic-backup-script/raw/main/restic-backup.sh
curl -LO https://github.com/buildplan/restic-backup-script/raw/main/restic-backup.conf
curl -LO https://github.com/buildplan/restic-backup-script/raw/main/restic-excludes.txt

# Set secure, executable permissions
chmod 700 restic-backup.sh
chmod 600 restic-backup.conf
```

### Step 3: Let the Script Manage Restic (Recommended)

When run from an interactive terminal, the script will offer to download and install the latest version of Restic. This process is secure: it fetches the official PGP-signed checksums from GitHub and verifies them before installing the binary. This is the recommended way to ensure system has latest version of Restic.

-----

## 2. Configuration

All operational settings are managed in `restic-backup.conf`. This centralized approach simplifies maintenance and keeps secrets out of the main script.

#### Key Configuration Fields:

  * **Repository & Password**

      * `RESTIC_REPOSITORY`: The location of backup repository. For SFTP, use the format `sftp:alias:/remote/path`, where `alias` is an entry in `/root/.ssh/config`.
      * `RESTIC_PASSWORD_FILE`: The absolute path to a file containing repository's encryption password (e.g., `/root/.restic-password`).

  * **Backup Sources**

      * `BACKUP_SOURCES`: A Bash array of absolute paths to back up. **Each path must be a separate, quoted element.** This syntax correctly handles paths with spaces.

    > ```bash
    > # Correct array syntax
    > BACKUP_SOURCES=("/var/www" "/home/user/my documents")
    > ```

  * **Backup Options**

      * `BACKUP_TAG`: A tag applied to each snapshot for easy identification (e.g., `daily-$(hostname)`).
      * `COMPRESSION`: Set to `auto`, `max`, or `off`. `max` is recommended for SFTP targets.
      * `ONE_FILE_SYSTEM`: If `true`, the backup will not cross filesystem boundaries (e.g., skip mounted drives within a source directory).

  * **Retention Policy**

      * `KEEP_LAST`, `KEEP_DAILY`, `KEEP_WEEKLY`, `KEEP_MONTHLY`, `KEEP_YEARLY`: Define how many snapshots to keep for each period during a `--forget` operation.

  * **Performance**

      * `LOW_PRIORITY`: Set to `true` to use `nice` and `ionice` to reduce the script's impact on system performance.

  * **Logging**

      * `LOG_FILE`: The path to the log file (e.g., `/var/log/restic-backup.log`).
      * `MAX_LOG_SIZE_MB` & `LOG_RETENTION_DAYS`: Configure automatic log rotation to manage disk space.

  * **Notifications & Monitoring**

      * `NTFY_ENABLED` / `DISCORD_ENABLED`: Enable and configure webhook URLs and tokens to receive alerts.
      * `HEALTHCHECKS_URL`: An optional URL to ping on successful completion, enabling "dead man's switch" monitoring.

  * **Exclusions**

      * `EXCLUDE_FILE`: Path to a file containing patterns to exclude, one per line.
      * `EXCLUDE_PATTERNS`: A space-separated string of patterns for quick exclusions.

-----

## 3. First-Time Setup

### Step 1: Configure Passwordless SSH Access (for SFTP)

Using an SSH config alias is the most reliable way to connect to remote repository.

1.  **Generate an SSH key for the `root` user** if one doesn't exist:

    ```sh
    sudo ssh-keygen -t ed25519 -f /root/.ssh/id_ed25519
    ```

    (Press Enter to accept the defaults).

2.  **Add the public key** (`/root/.ssh/id_ed25519.pub`) to remote server's `authorized_keys` file.

3.  **Create an SSH config file** at `/root/.ssh/config`:

    ```
    Host storagebox
        HostName u123456.your-storagebox.de
        User u123456
        Port 23
        IdentityFile /root/.ssh/id_ed25519
        ServerAliveInterval 60
    ```

4.  **Set permissions and test the connection:**

    ```sh
    sudo chmod 600 /root/.ssh/config
    sudo ssh storagebox pwd  # This should connect without a password
    ```

### Step 2: Create the Repository Password File

This file holds the master encryption key for backup repository. **Without this password, backed-up data is unrecoverable.**

```sh
# Replace 'your-very-secure-password' with a strong, unique password
echo 'your-very-secure-password' | sudo tee /root/.restic-password

# Set read-only permissions for root
sudo chmod 400 /root/.restic-password
```

### Step 3: Edit the Configuration File

Open `/root/scripts/backup/restic-backup.conf` and set `RESTIC_REPOSITORY`, `RESTIC_PASSWORD_FILE`, `BACKUP_SOURCES`, and desired notification and retention settings.

### Step 4: Initialize the Repository

Run the script with the `--init` flag to create the Restic repository on remote target. This is a one-time operation.

```sh
sudo /root/scripts/backup/restic-backup.sh --init
```

-----

## 4. Usage & Daily Operations

#### The Backup Lifecycle

When run, the script performs the following sequence:

1.  **Pre-flight Checks:** Verifies all dependencies, configuration files, source directories, and repository connectivity.
2.  **Locking:** Creates a lock file to ensure only one instance runs at a time.
3.  **Backup:** Executes `restic backup` with the options defined in configuration.
4.  **Retention:** (On default run) Applies the `forget` and `prune` policy if enabled.
5.  **Logging & Notifications:** Writes a detailed log and sends a status notification.
6.  **Health Check:** Pings Healthchecks.io URL if configured.

#### Common Commands

  * **Standard Backup:** `sudo ./restic-backup.sh`
      * Runs a standard backup and applies the retention policy. Designed for cron jobs.
  * **Verbose Mode:** `sudo ./restic-backup.sh --verbose`
      * Shows detailed, real-time progress in the terminal.
  * **Dry Run:** `sudo ./restic-backup.sh --dry-run`
      * Previews what files would be changed without creating a snapshot.
  * **Test Configuration:** `sudo ./restic-backup.sh --test`
      * Runs all pre-flight checks and reports success or failure. Perfect for validating setup.

-----

## 5. Scheduling with Cron

Automate backups by adding the script to the `root` user's crontab.

1.  Open the crontab editor: `sudo crontab -e`
2.  Add jobs for backup, retention, and periodic full checks.

<!-- end list -->

```crontab
# Ensure PATH includes /usr/local/bin where restic is often installed
PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

# Run a standard backup every day at 3:00 AM
0 3 * * * /root/scripts/backup/restic-backup.sh > /dev/null 2>&1

# Apply retention policy every Sunday at 4:00 AM (if not done after each backup)
0 4 * * 0 /root/scripts/backup/restic-backup.sh --forget > /dev/null 2>&1

# Run a full integrity check on the first Sunday of the month at 5:00 AM
0 5 * * 0 [ $(date +\%d) -le 07 ] && /root/scripts/backup/restic-backup.sh --check-full > /dev/null 2>&1
```

> Redirecting output to `/dev/null` is recommended, as the script handles its own logging and notifications.

-----

## 6. Restoring Data

The script includes a safe, interactive restore wizard to guide through the process.

**To start the wizard, run:** `sudo ./restic-backup.sh --restore`

The wizard will:

1.  List available snapshots to choose from.
2.  Ask if user wants to view the contents of the selected snapshot to find specific files.
3.  Prompt for a destination path.
4.  Allow user to specify particular files or directories to restore, or restore the entire snapshot.
5.  **Perform a dry run first** to show user exactly what will happen.
6.  Ask for final confirmation before starting the actual restore.

> **Ownership Handling:** If user restores to a directory under `/home` (e.g., `/home/someuser/restore`), the script will detect this and offer to automatically `chown` the restored files to the correct user.

-----

## 7. Repository Maintenance

#### Listing and Deleting Snapshots

  * **List all snapshots:** `sudo ./restic-backup.sh --snapshots`
  * **Interactively delete snapshots:** `sudo ./restic-backup.sh --snapshots-delete`
      * This provides a guided workflow to permanently remove one or more specific snapshots and then optionally prune the repository to reclaim space.

#### Integrity Checks

  * **Standard Check:** `sudo ./restic-backup.sh --check`
      * Verifies repository integrity by checking a random subset of data packs. This is fast and ideal for frequent checks.
  * **Full Check:** `sudo ./restic-backup.sh --check-full`
      * Verifies **all** data in the repository. This is slow and bandwidth-intensive but provides a complete guarantee of data integrity. Recommended to run monthly.

#### Handling Stale Locks

If a backup is interrupted, it may leave a stale lock file in the repository. The script prevents this with `flock`, but if a lock is present from another machine:

  * **Remove stale locks:** `sudo ./restic-backup.sh --unlock`
      * The script will first check for other running `restic` processes and ask for confirmation before forcibly removing the lock.

-----

## 8. Troubleshooting & Error Codes

Review the log file at `/var/log/restic-backup.log` for detailed error messages. The script uses specific exit codes to aid in debugging.

| Code | Meaning                                                                                                                |
| :--- | :--------------------------------------------------------------------------------------------------------------------- |
| `1`  | **Fatal Configuration Error:** `restic-backup.conf` is missing or a required variable is not set.                      |
| `5`  | **Lock Contention:** Another instance of the script is already running.                                                |
| `10` | **Missing Dependency:** A required command (`restic`, `curl`, `jq`, etc.) is not installed.                            |
| `11` | **Password File Error:** The `RESTIC_PASSWORD_FILE` cannot be found or read.                                           |
| `12` | **Repository Access Error:** Cannot connect to the repository. Check credentials, SSH config, or network connectivity. |
| `13` | **Source Path Error:** A directory in `BACKUP_SOURCES` does not exist or is not readable.                              |
| `14` | **Exclude File Error:** The `EXCLUDE_FILE` is defined but not readable.                                                |
| `15` | **Log File Error:** The `LOG_FILE` or its directory is not writable.                                                   |
| `20` | **Initialization Failed:** The `restic init` command failed.                                                           |

-----

## 9. Upgrading and Uninstalling

#### Upgrading the Script

When run interactively, the script automatically checks for new versions on GitHub. If an update is found, it will prompt to download and install it. The process verifies a checksum to ensure the downloaded file is authentic.

#### Uninstalling

1.  Remove the cron jobs with `sudo crontab -e`.
2.  Delete the script directory: `sudo rm -rf /root/scripts/backup`.
3.  Remove the password file: `sudo rm /root/.restic-password`.
4.  Remove the log file: `sudo rm /var/log/restic-backup.log`.

This will not affect any data already stored in remote Restic repository.
