---
layout: default
title: rsync Backup Script
nav_order: 9
parent: Home
last_modified_date: 2025-08-11T14:19:43+01:00
---

# Automated `rsync` Backup Script

This is a robust Bash script for automating secure, efficient backups to any remote server using `rsync` over SSH. While developed for use with a Hetzner Storage Box, it is designed to be adaptable to any remote destination accessible via SSH. It provides a reliable, configurable, and observable backup solution that can be deployed easily and managed via a single configuration file.

The script leverages `rsync` for its powerful differential transfer capabilities and wraps it in a layer of security, error handling, logging, and notification features suitable for a production environment.

-----

## Key Features

This script provides a complete backup framework with a focus on security, reliability, and ease of use.

  * **Unified & Secure Configuration**
    All settings, credentials, and exclusion lists are managed in a single `backup.conf` file, which should be secured with `chmod 600`. The script parses this file safely, using a whitelist to prevent an insecure configuration from affecting critical environment variables.

  * **Multi-Directory Support**
    The script is designed to back up multiple source directories in a single run. It uses `rsync`'s relative path feature (`-R`) and a special `/./` path anchor in the configuration to intelligently recreate the source directory structure on the destination, providing a clean and predictable backup layout.

  * **Production-Ready & Resilient**
    Built for reliability with features like file locking (`flock`) to prevent concurrent runs, automatic log rotation and retention to manage disk space, and `nice`/`ionice` to ensure the backup process has minimal impact on server performance.

  * **Rich Notifications & Reporting**
    Get detailed success, warning, or failure notifications sent to **ntfy** and/or **Discord**. Reports include key metrics like data transferred, files created, files updated, files deleted, and the total duration of the backup.

  * **Comprehensive Error Handling**
    The script operates under `set -Euo pipefail`, which enforces a strict error-checking environment:

      * `set -e`: Exits immediately if any command fails.
      * `set -u`: Exits if an unset variable is used.
      * `set -o pipefail`: A pipeline fails if any of its commands fail, not just the last one.
        A global `trap` also catches unexpected crashes, and the script intelligently handles specific `rsync` exit codes to distinguish between warnings (e.g., source files vanished during transfer) and hard failures.

  * **Versatile Operational Modes**
    In addition to the main backup mode, the script includes several interactive modes for diagnostics and management:

      * `--verbose`: Shows live `rsync` progress.
      * `--dry-run`: Simulates a backup and reports what would change.
      * `--checksum`: Verifies data integrity by comparing file checksums.
      * `--summary`: Provides a quick count of differing files.
      * `--test`: Runs all pre-flight checks to validate the configuration.
      * `--restore`: An interactive mode to safely restore files from the backup.

-----

## How It Works

The script's logic is centered around the `rsync` utility, which securely synchronizes files over an SSH connection.

1.  **Configuration**: The script begins by securely parsing the `backup.conf` file to load all operational parameters, including source directories, remote destination details, credentials, and exclusion patterns.
2.  **Pre-flight Checks**: Before execution, it runs a series of critical checks to ensure the environment is ready: it verifies that all required system commands are present, confirms passwordless SSH connectivity to the remote server, validates that all source directories exist and are readable, and checks for sufficient local disk space for logging.
3.  **Execution**: It uses `rsync` with the archive (`-a`) and relative (`-R`) flags. This combination efficiently copies only changed files while preserving permissions, timestamps, and ownership. The `-R` flag, combined with the `/./` anchor in the source paths (e.g., `/var/./www/`), tells `rsync` to recreate the "www" directory on the destination, ensuring a clean and intuitive directory structure.
4.  **Reporting**: After the `rsync` process completes, the script parses its machine-readable output to gather statistics. It then formats these stats into a human-readable summary and dispatches notifications based on the outcome (success, warning, or failure).
5.  **Automation**: The script is designed to be run non-interactively via a `cron` job, with file locking to ensure that scheduled runs do not overlap, which is critical for maintaining a consistent backup state.

-----

## Prerequisites

Before setup, ensure the required packages are installed on your server. While many of these are present on standard installations, explicitly installing them guarantees compatibility with minimal environments.

```sh
# On Debian or Ubuntu
sudo apt-get update && sudo apt-get install rsync curl coreutils util-linux

# On RHEL, CentOS, or Fedora
sudo dnf install rsync curl coreutils util-linux

# On Arch Linux
sudo pacman -S rsync curl coreutils util-linux
```

These commands provide `rsync`, `curl` (for notifications), and various essential system utilities like `flock`, `mktemp`, and `numfmt`.

-----

## Installation & Setup

#### A Note on Running as Root

It is strongly recommended to run this script as the **`root` user**. This is because backups often need to read system-critical files (e.g., in `/etc` or `/var/log`) that are inaccessible to other users. Running as root avoids permissions errors and ensures a complete backup. This requires that the script and its configuration file are stored in a secure location (like `/root/scripts/`) and that the `backup.conf` file has its permissions set to `600` to protect any stored credentials.

#### Step 1: Download Files

Place the `backup_script.sh` and `backup.conf` files in a dedicated, secure directory.

```sh
# Create the directory
sudo mkdir -p /root/scripts/backup && cd /root/scripts/backup

# 1. Get the script and make it executable
sudo wget https://github.com/buildplan/rsync-backup-script/raw/main/backup_script.sh
sudo chmod +x backup_script.sh

# 2. Get the config file
sudo wget https://github.com/buildplan/rsync-backup-script/raw/main/backup.conf
```

#### Step 2: Set Up SSH Key Authentication

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

    # Copy the key to the remote (replace with your details)
    sudo ssh-copy-id -p 23 u444300-sub4@u444300.your-storagebox.de
    ```

    This will ask for your remote password one last time to complete the setup.

3.  **Test the Connection**
    Verify that you can now log in without a password.

    ```sh
    sudo ssh -p 23 u444300-sub4@u444300.your-storagebox.de 'echo "Connection successful"'
    ```

    If this command runs without asking for a password, the setup is complete.

#### Step 3: Configure `backup.conf`

This is the central control file for the script. Secure it first, then edit it to match your environment.

```sh
sudo chmod 600 /root/scripts/backup/backup.conf
```

Below is an explanation of the key settings:

| Variable             | Description                                                                                                                                                                                           | Example                                      |
| :------------------- | :---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | :------------------------------------------- |
| `BACKUP_DIRS`        | A space-separated list of source directories. Each path must end with a `/` and use `/./` to define the directory structure you want on the remote. Example: `/var/./www/` creates a `www` directory at the destination. | `"/etc/./nginx/ /var/./www/"`                |
| `BOX_DIR`            | The base directory on the remote server where backups will be stored. **This path must end with a trailing slash (`/`)** for the restore logic to work correctly.                                        | `"/backups/my-server/"`                      |
| `HETZNER_BOX`        | The SSH connection string for the remote server in `user@host` format.                                                                                                                                | `"u444300-sub4@u444300.your-storagebox.de"` |
| `SSH_OPTS_STR`       | A string of additional options for the SSH command (e.g., custom port, identity file). The script safely converts this string to an array to prevent shell injection.                                    | `"-p 23"` or `"-p 22 -i /root/.ssh/backup_key"` |
| `LOG_FILE`           | The absolute path to the local log file.                                                                                                                                                              | `"/var/log/backup_rsync.log"`                |
| `LOG_RETENTION_DAYS` | The number of days to keep rotated log files before automatic deletion.                                                                                                                               | `90`                                         |
| `NTFY_ENABLED`       | Toggle ntfy notifications on (`true`) or off (`false`).                                                                                                                                               | `true`                                       |
| `DISCORD_ENABLED`    | Toggle Discord notifications on (`true`) or off (`false`).                                                                                                                                            | `false`                                      |
| `NTFY_PRIORITY_*`    | Set the priority level (1-5) for success, warning, and failure notifications on ntfy.                                                                                                                   | `NTFY_PRIORITY_FAILURE=4`                    |

-----

## Usage

#### Manual Execution

You can run the script manually at any time.

  * **Standard (Silent) Run**: `sudo /root/scripts/backup/backup_script.sh`
  * **Verbose Run with Live Progress**: `sudo /root/scripts/backup/backup_script.sh --verbose`

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

      * **Explanation**: The `>/dev/null 2>&1` part redirects all standard output (`stdout`) and standard error (`stderr`), preventing `cron` from sending unnecessary emails. This is safe because the script manages its own detailed logging and failure notifications. For help building cron schedules, you can use a tool like [crontab.guru](https://crontab.guru/).

#### Special Modes & Use Cases

  * `--dry-run`: Use this to safely preview changes before a major system upgrade or after modifying the exclusion list.
  * `--checksum`: Run this periodically (e.g., monthly) to verify the integrity of your backup archive and guard against silent data corruption. This is more CPU and I/O intensive than a standard backup.
  * `--summary`: A faster alternative to `--checksum` for a quick check to see if any files are out of sync.
  * `--test`: Run this once after setup and any time you modify `backup.conf` to ensure your configuration is valid before the next scheduled run.

-----

## Example: Using a Hetzner Storage Box

This script is ideal for backing up to a [Hetzner Storage Box](https://www.hetzner.com/storage/storage-box). For maximum security, creating a dedicated sub-account is recommended.

1.  **In your Hetzner Robot Panel**:

      * Navigate to your Storage Box -\> **Sub-accounts**.
      * Create a new sub-account (e.g., `u444300-sub5`).
      * Set its home directory to a dedicated top-level folder (e.g., `/`).
      * Set its access rights to **Read/Write**.
      * Disable all protocols except **SSH**.

2.  **Copy your SSH Key**: In the Hetzner panel for the main Storage Box account (not the sub-account), go to the **SSH Keys** section and paste the content of your server's root public key (`sudo cat /root/.ssh/id_ed25519.pub`).

3.  **Configure `backup.conf`**:

      * `HETZNER_BOX`: Use the **Username** from the sub-account and the **Hostname** of your Storage Box.
          * Example: `"u444300-sub5@u444300.your-storagebox.de"`
      * `BOX_DIR`: This path is relative to the sub-account's home directory. If the home directory is `/` and you want to store backups in a folder called `server1`, you would use `BOX_DIR="/server1/"`.
      * `SSH_OPTS_STR`: Set this to `"-p 23"`, as Hetzner Storage Boxes use port 23 for SSH access.
