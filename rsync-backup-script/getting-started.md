---
layout: default
title: rsync Backup Script
nav_order: 9
parent: Home
last_modified_date: 2025-08-13T17:42:00+01:00
---

# Automated `rsync` Backup Script

This is a robust Bash script for automating secure, efficient backups to any remote server using `rsync` over SSH. While developed for use with a Hetzner Storage Box, it is designed to be adaptable to any remote destination accessible via SSH. It provides a reliable, configurable, and observable backup solution that can be deployed easily and managed via a single configuration file.

The script leverages `rsync` for its powerful differential transfer capabilities and wraps it in a layer of security, error handling, logging, and notification features suitable for a production environment.

---

## Key Features

This script provides a complete backup framework with a focus on security, reliability, and ease of use.

* **Unified & Secure Configuration**
    All settings, credentials, and exclusion lists are managed in a single `backup.conf` file, which should be secured with `chmod 600`. The script parses this file safely, using a whitelist to prevent an insecure configuration from affecting critical environment variables.

* **Advanced Restore Functionality**
    A powerful interactive restore mode (`--restore`) allows you to recover data with precision. It supports:
    * **Granular Selection**: Restore an entire backup set, a specific sub-folder, or even a single file.
    * **Recycle Bin Recovery**: Browse a time-stamped history of deleted files in the remote recycle bin and restore them to their original locations.
    * **Safe Operations**: All restores include a mandatory dry-run preview and a confirmation step to prevent accidents.
    * **Permission Handling**: Automatically sets the correct user ownership on files restored into `/home/` directories.

* **Intelligent Recycle Bin**
    Instead of permanently deleting files that are removed from the source, the script can move them to a remote recycle bin. Each backup run creates a unique, time-stamped folder (e.g., `YYYY-MM-DD_HHMMSS`), preventing overwrites and allowing you to recover a file exactly as it was at a specific point in time. Old items are automatically purged based on a configurable retention period.

* **Production-Ready & Resilient**
    Built for reliability with features like file locking (`flock`) to prevent concurrent runs, configurable log rotation to manage disk space, and a filesystem `sync` to ensure all recent file changes are captured. It uses `nice`/`ionice` to minimize its impact on server performance.

* **Rich Notifications & Reporting**
    Get detailed success, warning, or failure notifications sent to **ntfy** and/or **Discord**. Reports include key metrics like data transferred, files created/updated/deleted, a list of processed directories, and the total duration of the backup. Long notifications are automatically truncated to prevent them from being cut off by API limits.

* **Comprehensive Error Handling**
    The script operates under `set -Euo pipefail`, which enforces a strict error-checking environment. A global `trap` catches unexpected crashes, and the script intelligently handles specific `rsync` exit codes (23 and 24) to distinguish between non-critical warnings and hard failures.

* **Versatile Operational Modes**
    In addition to the main backup and restore modes, the script includes several flags for diagnostics and management:
    * `--verbose`: Shows live `rsync` progress.
    * `--dry-run`: Simulates a backup and reports what would change.
    * `--checksum`: Verifies data integrity by comparing file checksums (slower).
    * `--summary`: Provides a quick count of differing files (faster).
    * `--test`: Runs all pre-flight checks to validate the configuration and environment.
    * `--restore`: An interactive mode to safely restore files from the backup.

---

## How It Works

The script's logic is centered around the `rsync` utility, which securely synchronizes files over an SSH connection.

1.  **Configuration**: The script begins by securely parsing the `backup.conf` file to load all operational parameters, including source directories, remote destination details, and exclusion patterns.
2.  **Pre-flight Checks**: Before execution, it runs a series of critical checks: it verifies that all required system commands are present, confirms passwordless SSH connectivity, validates the configuration (e.g., path formats), and ensures the remote recycle bin is accessible if enabled.
3.  **Execution**: It uses `rsync` with the archive (`-a`) and relative (`-R`) flags. This combination efficiently copies only changed files while preserving metadata. The `/./` anchor in the source paths (e.g., `/var/./www/`) tells `rsync` to recreate the `www` directory at the destination, ensuring a clean directory structure.
4.  **Reporting**: After the `rsync` process completes, the script parses its output to gather statistics. It then formats these into a human-readable summary and dispatches notifications based on the outcome (success, warning, or failure).
5.  **Automation**: The script is designed to be run non-interactively via a `cron` job, with file locking to ensure that scheduled runs do not overlap.

---

## Prerequisites

Before setup, ensure the required packages are installed on your server. While many of these are present on standard installations, explicitly installing them guarantees compatibility with minimal environments.

```sh
# On Debian or Ubuntu
sudo apt-get update && sudo apt-get install rsync curl coreutils util-linux

# On RHEL, CentOS, or Fedora
sudo dnf install rsync curl coreutils util-linux

# On Arch Linux
sudo pacman -S rsync curl coreutils util-linux
````

These commands provide `rsync`, `curl` (for notifications), and various essential system utilities like `flock`, `mktemp`, `nice`, and `numfmt`.

-----

## Installation & Setup

### A Note on Running as Root

It is **strongly recommended** to run this script as the `root` user. This is because backups often need to read system-critical files (e.g., in `/etc` or `/var/log`) that are inaccessible to other users. Running as root avoids permissions errors and ensures a complete backup. This requires that the script and its configuration file are stored in a secure location (like `/root/scripts/`) and that the `backup.conf` file has its permissions set to `600` to protect any stored credentials.

### Step 1: Download Files

Place the `backup_script.sh` and `backup.conf` files in a dedicated, secure directory.

```sh
# Create the directory
sudo mkdir -p /root/scripts/backup && cd /root/scripts/backup

# Get the script and make it executable
wget https://github.com/buildplan/rsync-backup-script/raw/refs/heads/main/backup_script.sh && chmod +x backup_script.sh

# Get the config file and set secure permissions
wget https://github.com/buildplan/rsync-backup-script/raw/refs/heads/main/backup.conf && chmod 600 backup.conf
```

### Step 2: Set Up SSH Key Authentication

For automation via `cron`, the script must connect to the remote server without a password prompt. This is achieved using SSH key-pair authentication. A **passphrase-less** key is required, as there will be no user present to enter a passphrase during a scheduled run.

1.  **Generate an SSH Key for Root**
    If the `root` user does not already have an SSH key, generate one. `ed25519` is the modern, recommended standard.

    ```sh
    sudo ssh-keygen -t ed25519
    ```

    When prompted, press **Enter** to accept the default file location (`/root/.ssh/id_ed25519`) and press **Enter** again (for an empty passphrase) to create the key.

2.  **Copy the Public Key to the Remote Server**
    This step authorizes your server's `root` user to log into the remote backup destination. The `ssh-copy-id` command is the simplest method.

    ```sh
    # View the public key first (optional)
    sudo cat /root/.ssh/id_ed25519.pub

    # Copy the key to the remote (replace with your user@host and port for Hertzner add -s flag)
    sudo ssh-copy-id -p 22 user@remote-server.com
    ```

    This will ask for your remote password one last time to complete the setup.

3.  **Test the Connection**
    Verify that you can now log in without a password.

    ```sh
    # Replace with your user@host and port
    sudo ssh -p 22 user@remote-server.com 'echo "Connection successful"'
    ```

    If this command runs without asking for a password, the setup is complete.

### Step 3: Configure `backup.conf`

This is the central control file for the script. Secure it first, then edit it to match your environment.

```sh
sudo chmod 600 /root/scripts/backup/backup.conf
```

Below is an explanation of the key settings available in the `backup.conf` file:

| Variable | Description | Example |
| :--- | :--- | :--- |
| **`BACKUP_DIRS`** | A space-separated list of source directories. Each path must end with a `/` and use `/./` to define the relative path to be created on the remote. | `"/etc/./nginx/ /var/./www/"` |
| **`BOX_DIR`** | The base directory on the remote server where backups will be stored. **Must end with a trailing slash (`/`)**. | `"/backups/my-server/"` |
| **`BOX_ADDR`** | The SSH connection string for the remote server in `user@host` format. | `"user@your-storagebox.de"` |
| **`BEGIN_SSH_OPTS...END_SSH_OPTS`** | A block for adding custom SSH options like a port (`-p 23`) or identity file (`-i /path/to/key`). Place each option on a new line. | See config file |
| **`BEGIN_EXCLUDES...END_EXCLUDES`** | A block for adding file and directory patterns to exclude from the backup, one per line. | See config file |
| **`LOG_FILE`** | The absolute path to the local log file. | `"/var/log/backup_rsync.log"` |
| **`MAX_LOG_SIZE_MB`** | The maximum size in Megabytes (MB) for the log file before it is automatically rotated. | `10` |
| **`LOG_RETENTION_DAYS`** | The number of days to keep rotated log files before automatic deletion. | `90` |
| **`BANDWIDTH_LIMIT_KBPS`** | Optional. Throttles `rsync`'s network speed. Value is in KBytes/sec (e.g., 5000 = 5 MB/s). Leave empty or `0` to disable. | `5000` |
| **`RSYNC_TIMEOUT`** | The timeout in seconds for `rsync` network operations. A higher value is safer for slow or unstable connections. | `300` |
| **`RSYNC_NOATIME_ENABLED`**| Set to `true` for a performance boost. Requires `rsync` v3.3.0+ on **both** local and remote servers. Set to `false` for older servers. | `false` |
| **`RECYCLE_BIN_ENABLED`** | Toggle the recycle bin feature on (`true`) or off (`false`). When off, deleted files are permanently removed. | `true` |
| **`RECYCLE_BIN_DIR`** | The name of the recycle bin folder on the remote, relative to `BOX_DIR`. | `"recycle_bin"` |
| **`RECYCLE_BIN_RETENTION_DAYS`** | The number of days to keep items in the recycle bin before they are automatically purged. | `30` |
| **`CHECKSUM_ENABLED`** | Set to `true` to enable slow but highly accurate integrity checks using file checksums. Defaults to fast checks (size & time). | `false` |
| **`NTFY_ENABLED`** | Toggle ntfy notifications on (`true`) or off (`false`). | `true` |
| **`DISCORD_ENABLED`** | Toggle Discord notifications on (`true`) or off (`false`). | `false` |
| **`NTFY_PRIORITY_*`** | Set the priority level (1-5) for success, warning, and failure notifications on ntfy. | `NTFY_PRIORITY_FAILURE=5` |

-----

## Usage

### Manual Execution

You can run the script manually at any time to perform backups or maintenance tasks.

  * **Standard Run**: `sudo /root/scripts/backup/backup_script.sh`
  * **Verbose Run with Live Progress**: `sudo /root/scripts/backup/backup_script.sh --verbose`

### Scheduling with Cron

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

      * **Explanation**: The `>/dev/null 2>&1` part redirects all standard output (`stdout`) and standard error (`stderr`), preventing `cron` from sending unnecessary emails. This is safe because the script manages its own detailed logging and failure notifications. For help building cron schedules, you can use a tool like [crontab.guru](https://crontab.guru/).

### Special Modes & Use Cases

  * **`--restore`**: Launch the powerful interactive restore wizard to recover files from a primary backup or the recycle bin.
  * **`--dry-run`**: Use this to safely preview changes before a major system upgrade or after modifying the exclusion list.
  * **`--checksum`**: Run this periodically (e.g., monthly) to verify the integrity of your backup archive and guard against silent data corruption. This is more CPU and I/O intensive than a standard backup.
  * **`--summary`**: A faster alternative to `--checksum` for a quick check to see if any files are out of sync.
  * **`--test`**: Run this once after setup and any time you modify `backup.conf` to ensure your configuration is valid before the next scheduled run.

-----

## Example: Using a Hetzner Storage Box

This script is ideal for backing up to a [Hetzner Storage Box](https://www.hetzner.com/storage/storage-box). For maximum security, creating a dedicated sub-account is recommended.

1.  **In your Hetzner Robot Panel**:

      * Navigate to your Storage Box → **Sub-accounts**.
      * Create a new sub-account (e.g., `u444300-sub5`).
      * Set its home directory to a dedicated top-level folder (e.g., `/`).
      * Set its access rights to **Read/Write**.
      * Disable all protocols except **SSH/SFTP**.

2.  **Copy your SSH Key**: In the Hetzner panel for the main Storage Box account (not the sub-account), go to the **SSH Keys** section and paste the content of your server's root public key (`sudo cat /root/.ssh/id_ed25519.pub`).

3.  **Configure `backup.conf`**:

      * **`BOX_ADDR`**: Use the **Username** from the sub-account and the **Hostname** of your Storage Box.
          * Example: `"u444300-sub5@u444300.your-storagebox.de"`
      * **`BOX_DIR`**: This path is relative to the sub-account's home directory. If the home directory is `/` and you want to store backups in a folder called `server1`, you would use `BOX_DIR="/server1/"`.
      * **`BEGIN_SSH_OPTS` block**: Add `-p 23` on a new line inside this block, as Hetzner Storage Boxes use port 23 for SSH access.
