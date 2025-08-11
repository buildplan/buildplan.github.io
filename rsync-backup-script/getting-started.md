---
layout: default
title: `rsync` Backup Script
nav_order: 9
parent: Home
last_modified_date: 2025-08-11T09:30:43+01:00
---

# Automated `rsync` Backup Script

A robust Bash script for automating secure, efficient backups to any remote server over SSH. It is designed for my peronal use and I use Hetzner Storage Box but can be adopted to use with any other remote backup solution. it's a reliable, configurable, and observable backup solution that can be deployed easily and managed via a single configuration file.

The script leverages `rsync` for its powerful differential backup capabilities and wraps it in a layer of security, error handling, logging, and notification features suitable for any production environment.

## Key Features

This script is more than just a simple `rsync` command; it's a complete backup framework with a focus on security, reliability, and ease of use.

  * **Unified & Secure Configuration**
    All settings, credentials, and exclusion lists are managed in a single `backup.conf` file. The script parses this file safely, using a whitelist to prevent an insecure configuration from overwriting critical environment variables.

  * **Multi-Directory Support**
    The script is designed to back up multiple source directories in a single run. It uses `rsync`'s `--relative` (`-R`) flag to intelligently recreate the source directory structure on the destination, providing a clean and predictable backup layout.

  * **Production-Ready & Resilient**
    Built for reliability with features like file locking (`flock`) to prevent concurrent runs, automatic log rotation and retention to manage disk space, and `nice`/`ionice` to ensure the backup process has minimal impact on server performance.

  * **Rich Notifications & Reporting**
    Get detailed success, warning, or failure notifications sent to **ntfy** and/or **Discord**. Reports include key metrics like data transferred, files created, updated, and deleted, and the total duration of the backup.

  * **Comprehensive Error Handling**
    The script operates under `set -Euo pipefail`, ensuring it exits immediately on any error. A global `trap` catches unexpected crashes, and the script intelligently handles specific `rsync` exit codes to distinguish between warnings (e.g., source files vanished) and hard failures.

  * **Versatile Operational Modes**
    In addition to the main backup mode, the script includes several interactive modes for diagnostics and testing:

      * `--verbose`: Shows live `rsync` progress.
      * `--dry-run`: Simulates a backup and reports what would change.
      * `--checksum`: Verifies data integrity by comparing file checksums.
      * `--summary`: Provides a quick count of differing files.
      * `--test`: Runs all pre-flight checks to validate the configuration.

## How It Works

The script's logic is centered around the `rsync` utility, which securely synchronizes files over an SSH connection.

1.  **Configuration**: The script begins by securely parsing the `backup.conf` file to load all operational parameters, including source directories, remote destination details, credentials, and exclusion patterns.
2.  **Pre-flight Checks**: Before execution, it runs a series of critical checks to ensure the environment is ready: it verifies that all required system commands are present, confirms passwordless SSH connectivity to the remote server, validates that all source directories exist and are readable, and checks for sufficient local disk space for logging.
3.  **Execution**: It uses `rsync` with the archive (`-a`) and relative (`-R`) flags. This combination efficiently copies only changed files while preserving permissions, timestamps, and ownership. The `-R` flag, combined with the `/./` anchor in the source paths, ensures a clean directory structure on the destination.
4.  **Reporting**: After the `rsync` process completes, the script parses the machine-readable output to gather statistics. It then formats these stats into a human-readable summary and dispatches notifications based on the outcome (success, warning, or failure).
5.  **Automation**: The script is designed to be run non-interactively via a `cron` job, with file locking to ensure reliability in a scheduled environment.

## Prerequisites

Before setup, ensure the following packages are installed on your server. On Debian or Ubuntu, you can install them with:

```sh
sudo apt-get update && sudo apt-get install rsync curl coreutils util-linux
```

This provides `rsync` for the backup, `curl` for notifications, and various essential system utilities like `flock`, `mktemp`, and `numfmt`.

## Installation & Setup

#### Step 1: Download Files

Place the `backup_script.sh` and `backup.conf` files in a dedicated directory.

```sh
# Create the directory
mkdir -p /root/scripts/backup && cd /root/scripts/backup

# 1. Get the script and make it executable
wget https://github.com/buildplan/rsync-backup-script/raw/main/backup_script.sh
chmod +x backup_script.sh

# 2. Get the config file
wget https://github.com/buildplan/rsync-backup-script/raw/main/backup.conf
```

*Note: It is strongly recommended to run this script as the `root` user to avoid permissions issues when backing up system files.*

#### Step 2: Set Up SSH Key Authentication

For automation, the script must connect to the remote server without a password prompt. This is achieved using SSH key-pair authentication.

1.  **Generate an SSH Key for Root**
    If the `root` user does not already have an SSH key, generate one. `ed25519` is the modern, recommended standard.

    ```sh
    sudo ssh-keygen -t ed25519
    ```

    Press Enter to accept the default file location and to create a key without a passphrase.

2.  **Copy the Public Key to the Remote Server**
    This step authorizes your server's `root` user to log into the remote backup destination. The `ssh-copy-id` command is the simplest way to do this.

    ```sh
    # View the public key first (optional)
    sudo cat /root/.ssh/id_ed25519.pub

    # Copy the key to the remote (replace with your details)
    sudo ssh-copy-id -p 23 u444300-sub4@u444300.your-storagebox.de
    ```

    This will ask for your remote password one last time to complete the setup.

3.  **Test the Connection**
    Verify that you can now log in as `root` without a password.

    ```sh
    sudo ssh -p 23 u444300-sub4@u444300.your-storagebox.de 'echo "Connection successful"'
    ```

    If this command runs without asking for a password, the setup is complete.

#### Step 3: Configure `backup.conf`

This is the central control file for the script. Edit it to match your environment.

```sh
# Set secure permissions for the config file
chmod 600 backup.conf
```

Below is an explanation of the key settings:

| Variable | Description | Example |
| :--- | :--- | :--- |
| `BACKUP_DIRS` | A space-separated list of source directories. **Crucially**, each path must end with a `/` and use `/./` to define the directory structure you want on the remote. | `"/etc/./nginx/ /var/./www/"` |
| `BOX_DIR` | The base directory on the remote server where backups will be stored. Must end with a `/`. | `"/backups/my-server/"` |
| `HETZNER_BOX` | The SSH connection string for the remote server. | `"u444300-sub4@u444300.your-storagebox.de"` |
| `SSH_OPTS_STR` | A string of additional options for the SSH command. | `"-p 23"` or `"-p 22 -i /root/.ssh/backup_key"` |
| `LOG_FILE` | The absolute path to the local log file. | `"/var/log/backup_rsync.log"` |
| `LOG_RETENTION_DAYS` | The number of days to keep rotated log files. | `90` |
| `NTFY_ENABLED` | Toggle ntfy notifications on (`true`) or off (`false`). | `true` |
| `DISCORD_ENABLED`| Toggle Discord notifications on (`true`) or off (`false`). | `false` |
| `NTFY_PRIORITY_*`| Set the priority level (1-5) for success, warning, and failure notifications on ntfy. | `NTFY_PRIORITY_FAILURE=4` |

## Usage

#### Manual Execution

You can run the script manually at any time. All commands must be run with `sudo` or as the `root` user.

  * **Standard (Silent) Run**: `sudo ./backup_script.sh`
  * **Verbose Run with Live Progress**: `sudo ./backup_script.sh --verbose`

#### Scheduling with Cron

For automated backups, schedule the script using the `root` user's crontab.

1.  Open the root crontab editor:

    ```sh
    sudo crontab -e
    ```

2.  Add a line to define the schedule. This example runs the backup every night at 3:00 AM.

    ```crontab
    # Run the rsync backup every day at 3:00 AM
    0 3 * * * /root/scripts/backup/backup_script.sh >/dev/null 2>&1
    ```

      * **Explanation**: The `>/dev/null 2>&1` part redirects all standard output and error messages, preventing `cron` from sending unnecessary emails. This is safe because the script manages its own logging and failure notifications.

#### Special Modes

  * `--dry-run`: Performs a full simulation of the backup and generates a report of what files would be created, updated, or deleted without making any actual changes.
  * `--checksum`: Verifies the integrity of the backup by comparing file checksums between the source and destination. This is slower than a normal backup but is the most thorough way to check for data corruption.
  * `--summary`: Provides a quick count of files that differ between the source and destination.
  * `--test`: Runs all pre-flight checks (dependencies, SSH, config) and reports the results without starting a backup. This is useful for validating your setup.

## Example: Using a Hetzner Storage Box

This script is ideal for backing up to a [Hetzner Storage Box](https://www.hetzner.com/storage/storage-box). For maximum security, it's recommended to create a dedicated sub-account for your backups.

1.  **In your Hetzner Robot Panel**:

      * Navigate to your Storage Box -\> Sub-accounts.
      * Create a new sub-account (e.g., `my-server-backup`).
      * Set its home directory to a dedicated folder (e.g., `/backups`).
      * Set its permissions to **Read/Write**.
      * Disable all other protocols except SSH.

2.  **Copy your SSH Key**: Copy the `root` public key from your server (`sudo cat /root/.ssh/id_ed25519.pub`) and paste it into the "SSH Keys" section for the Storage Box in the main Hetzner panel.

3.  **Configure `backup.conf`**:

      * `HETZNER_BOX`: Use the **Username** from the sub-account and the **Hostname** of your Storage Box (e.g., `"u444300-sub1@u444300.your-storagebox.de"`).
      * `BOX_DIR`: This should be the path on the Storage Box where backups will be stored, relative to the sub-account's home directory. If the home directory is `/backups` and you want to store backups in a folder called `my-server`, you would use `BOX_DIR="/my-server/"`.
      * `SSH_OPTS_STR`: Set this to `"-p 23"` as Storage Boxes use port 23 for SSH.
