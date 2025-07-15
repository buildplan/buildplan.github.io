---
layout: default
title: Container Monitor
nav_order: 8
parent: Home
last_modified_date: 2025-07-15T07:53:43+01:00
---

# Container Monitor Documentation

**Container Monitor** is a comprehensive Bash script for monitoring Docker containers. It automates checks for container health, resource usage, and available image updates, and can send notifications if it finds any issues.

This document provides a complete guide to installing, configuring, and using the script.

---
## Purpose and Design

The script is designed to automate routine monitoring tasks for Docker environments. Its primary objectives are:

1.  **Automation**: To perform scheduled health and version checks and notify an administrator only when attention is needed.
2.  **Functionality**: To provide detailed checks that go beyond standard `docker` commands, such as detecting updates for both `:latest` and version-pinned tags.
3.  **Clarity**: To present information in a clean, human-readable format with color-coded terminal output and a final summary report for easy diagnosis.

---
## Key Features

* **Asynchronous Checks**: Runs checks on multiple containers in parallel for faster execution on hosts with many containers.
* **Interactive Updates**: Provides a special mode to scan for updates and allow the user to interactively choose which new images to pull.
* **Advanced Update Detection**:
    * For `:latest` tags, it compares image digests to detect new builds.
    * For versioned tags (e.g., `image:2.10`), it scans the remote repository for the latest stable version (e.g., `2.11`), while ignoring pre-release tags like `-beta` or `-rc`.
* **Release Note Integration**: Displays a direct link to release notes when an update is available, providing immediate context for the new version.
* **Health Monitoring**: Checks container status, restart counts, and Docker's built-in health checks (`healthy`/`unhealthy`).
* **Resource Monitoring**: Tracks CPU and Memory usage against configurable thresholds.
* **Log Scanning**: Scans recent container logs for keywords like `error`, `panic`, and `fatal`.
* **Self-Updating**: The script can check its source repository and prompt for an update to the latest version.
* **Flexible Notifications**: Sends alerts for any detected issues to Discord or a self-hosted ntfy server.

---
## Getting Started

### Prerequisites

The script requires the following command-line tools to be installed on the host system:

* `docker`
* `jq`
* `skopeo`
* `coreutils` (provides `timeout`)
* `gawk` (provides `awk`)

For **Debian-based systems** (e.g., Ubuntu, Debian), you can install them with:

```bash
sudo apt-get update
sudo apt-get install -y skopeo jq coreutils gawk
````

### Installation

**1. Download the Project Files**

```bash
# Download the main script
wget [https://github.com/buildplan/container-monitor/raw/main/container-monitor.sh](https://github.com/buildplan/container-monitor/raw/main/container-monitor.sh)

# Download the main configuration file
wget [https://github.com/buildplan/container-monitor/raw/main/config.sh](https://github.com/buildplan/container-monitor/raw/main/config.sh)

# Download the example release notes URL file
wget [https://github.com/buildplan/container-monitor/raw/main/release_urls.conf](https://github.com/buildplan/container-monitor/raw/main/release_urls.conf)
```

**2. Verify Script Integrity (Recommended)**
To ensure the script is authentic, verify its SHA256 checksum against the official one.

```bash
# Download the official checksum file
wget [https://github.com/buildplan/container-monitor/raw/main/container-monitor.sh.sha256](https://github.com/buildplan/container-monitor/raw/main/container-monitor.sh.sha256)

# Run the check. The output should be: container-monitor.sh: OK
sha256sum -c container-monitor.sh.sha256
```

**3. Make it Executable**

```bash
chmod +x container-monitor.sh
```

-----

## Configuration

The script's behavior is controlled through a clear configuration hierarchy. Settings are loaded in the following order, with later sources overriding earlier ones:

1.  **Script Defaults**: Hardcoded default values within the script.
2.  **`config.sh` File**: User-defined defaults set in this file.
3.  **Environment Variables**: The highest priority, overriding all other settings.

#### `config.sh`

This is the primary file for setting your monitoring defaults. Open it in a text editor to configure thresholds, notification channels, and the default list of containers to monitor.

#### `release_urls.conf`

This optional file maps container images to their official release notes page. The script uses this to provide direct links in update notifications. The format is `image_name=url`, for example:

```
# Format: <docker_image_name_without_tag>=<url_to_release_notes>
portainer/portainer-ce=[https://github.com/portainer/portainer/releases](https://github.com/portainer/portainer/releases)
```

-----

## Command-Line Usage

The script offers several command-line flags and arguments for different modes of operation.

#### Running Monitor Checks

  * **Run a standard check:**
    `./container-monitor.sh`
    (Monitors containers from `config.sh` or all running containers if none are specified.)

  * **Run a check on specific containers:**
    `./container-monitor.sh traefik crowdsec`

  * **Run a check excluding specific containers:**
    `./container-monitor.sh --exclude=portainer,unifi-controller`

  * **Run in Summary-Only Mode (for automation):**
    `./container-monitor.sh summary`
    (Suppresses detailed output and shows only the final summary report.)

#### Managing Updates

  * **Interactively update containers:**
    `./container-monitor.sh --interactive-update`
    (Scans for updates and presents a menu to pull new images.)

  * **Skip the self-update check:**
    `./container-monitor.sh --no-update`

#### Viewing Logs

  * **Show recent logs for a container:**
    `./container-monitor.sh logs traefik`

  * **Show only error-related lines from logs:**
    `./container-monitor.sh logs errors traefik`

  * **Save full logs for a container to a file:**
    `./container-monitor.sh save logs traefik`

-----

## Core Components Explained

Each container check is broken down into several functions, each responsible for a specific aspect of monitoring.

  * `check_container_status`
    Checks if the container is running and evaluates its health status. A warning is triggered if the container is not `running` or if its health check is `unhealthy`.

  * `check_container_restarts`
    Checks the container's restart count. A warning is triggered if the count is greater than zero, as this can indicate a crash loop or configuration issue.

  * `check_resource_usage`
    Monitors CPU and Memory usage as a percentage. It compares these values against the `CPU_WARNING_THRESHOLD` and `MEMORY_WARNING_THRESHOLD` from the configuration and triggers a warning if either is exceeded.

  * `check_disk_space`
    Inspects the container's mounts and checks the disk usage of each volume or bind mount. A warning is triggered if usage exceeds the `DISK_SPACE_THRESHOLD`. It intelligently skips virtual filesystems like `/proc` or socket files.

  * `check_network`
    Reads the container's network interface statistics from `/proc/net/dev`. A warning is triggered if the sum of receive errors and transmit drops on any interface exceeds the `NETWORK_ERROR_THRESHOLD`.

  * `check_for_updates`
    This is the most complex check. It uses `skopeo` to inspect the remote container registry.

      * If the image tag is `:latest`, it compares the local image's SHA256 digest with the remote digest. A mismatch indicates a new version has been published.
      * If the image tag is a version string (e.g., `v1.2.3`), it lists all tags in the remote repository, filters for stable semantic versions (ignoring `-dev`, `-rc`, etc.), and identifies the highest version number. A warning is triggered if a newer stable version is found.

  * `check_logs`
    Retrieves the most recent log entries (the number of lines is configurable) and scans them for keywords such as `error`, `panic`, `fail`, or `fatal`. A warning is triggered if any of these keywords are found.

-----

## Automated Execution

The script is designed for automated execution by a scheduler. Using the `summary` and `--no-update` flags is highly recommended for automation.

#### Option A: systemd Timer Setup

This method is robust and provides excellent logging via the system journal. Create the following two files in `/etc/systemd/system/`.

**`docker-monitor.service`**

```ini
[Unit]
Description=Run Docker Container Monitor Script

[Service]
Type=oneshot
ExecStart=/path/to/your/container-monitor.sh --no-update summary
```

**`docker-monitor.timer`**

```ini
[Unit]
Description=Run Docker Container Monitor every 6 hours

[Timer]
OnBootSec=10min
OnUnitActiveSec=6h
Persistent=true

[Install]
WantedBy=timers.target
```

Then, enable and start the timer:

```bash
sudo systemctl enable --now docker-monitor.timer
```

#### Option B: Cron Job Setup

Use `cron` for a simpler setup. Edit your crontab with `crontab -e` and add the following line:

```crontab
0 */6 * * * /path/to/your/container-monitor.sh --no-update summary >/dev/null 2>&1
```

The redirection `>/dev/null 2>&1` prevents cron from sending emails for routine runs, as the script handles its own notifications.

-----

## Use Cases and Limitations

#### Intended Use Cases

  * **Home Labs**: Ideal for monitoring personal media servers, home automation systems, and other self-hosted services.
  * **Small Deployments**: Well-suited for a single server running a critical set of applications for a small business or project.
  * **Developer Workstations**: A useful tool for quickly checking the status of a local development environment running in Docker.

#### Limitations

  * **Not a Time-Series System**: The script performs periodic checks and sends state-in-time alerts. It does not store historical data for graphing or trending, unlike systems such as Prometheus.
  * **Single-Host Focus**: The script is designed to monitor a single Docker host. It is not intended for managing a large fleet of servers, where centralized, agent-based systems are more appropriate.
  * **Registry-Dependent Update Checks**: Update detection is most reliable for repositories that follow standard semantic versioning practices.
