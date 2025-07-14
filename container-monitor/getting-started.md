---
layout: default
title: Container Monitor
nav_order: 8
parent: Home
last_modified_date: 2025-07-14T17:30:27+01:00
---

# Container Monitor Documentation

**Container Monitor** is a Bash script for monitoring Docker containers. It automates checks for container health, resource usage, and available image updates, and can send notifications if it finds any issues.

This document provides a complete guide to installing, configuring, and using the script.

-----

## Purpose and Design

The script is designed to automate routine monitoring tasks for Docker environments. It addresses the following objectives:

1.  **Automation**: To perform scheduled health and version checks and notify an administrator only when attention is needed.
2.  **Functionality**: To provide detailed checks that go beyond standard `docker` commands, such as detecting updates for version-pinned tags.
3.  **Clarity**: To present information in a clean, human-readable format with color-coded terminal output and a final summary report.

-----

## Key Features

The script includes several features for server administrators and developers:

  * **Asynchronous Checks**: Runs checks on multiple containers in parallel for faster execution on hosts with many containers.
  * **Self-Updating**: The script can check its source repository and prompt for an update to the latest version.
  * **Health Monitoring**: Checks container status, restart counts, and Docker's built-in health checks (`healthy`/`unhealthy`).
  * **Resource Monitoring**: Tracks CPU and Memory usage against configurable thresholds.
  * **Disk Usage Checks**: Reports on disk space usage for container volumes and bind mounts. It is configured to ignore virtual/special paths and only report on high usage to reduce output noise.
  * **Update Detection**:
      * For `:latest` tags, it compares image digests to detect new builds.
      * For version-pinned tags (e.g., `image:2.10`), it scans the remote repository for the latest stable version (e.g., `2.11`), while ignoring pre-release tags like `-beta` or `-rc`.
  * **Notifications**: Sends alerts for any detected issues to Discord or a self-hosted ntfy server.
  * **Progress Bar**: Displays a progress bar with a percentage, counter, and elapsed time during interactive runs.

-----

## Getting Started

### Prerequisites

The script requires the following command-line tools:

  * `docker`
  * `jq`
  * `skopeo`
  * `coreutils` (provides `timeout`)
  * `gawk` (provides `awk`)

For **Debian-based systems** (e.g., Ubuntu, Debian), you can install them with:

```bash
sudo apt-get update
sudo apt-get install -y skopeo jq coreutils gawk
```

### Installation

**1. Download the Files**
Download the script and its configuration file from the GitHub repository.

```bash
# Download the main script
wget https://github.com/buildplan/container-monitor/raw/main/container-monitor.sh

# Download the configuration file
wget https://github.com/buildplan/container-monitor/raw/main/config.sh
```

**2. Verify Script Integrity (Recommended)**
To ensure the script is authentic, verify its SHA256 checksum.

```bash
# Download the official checksum file
wget https://github.com/buildplan/container-monitor/raw/main/container-monitor.sh.sha256

# Run the check. The output should be: container-monitor.sh: OK
sha256sum -c container-monitor.sh.sha256
```

**3. Make it Executable**

```bash
chmod +x container-monitor.sh
```

### Configuration

All default settings are managed in the `config.sh` file. These settings can be overridden by exporting environment variables of the same name. Open `config.sh` to set your monitoring defaults.

-----

## Automated Execution

The script is intended for automated, periodic execution via a scheduler like `systemd` or `cron`.

**Key Flags for Automation:**

  * `--no-update`: Prevents the script from interactively prompting for a self-update.
  * `summary`: Restricts output to only the final summary report, which is ideal for system logs.

### Option A: systemd Timer Setup

This method provides robust logging and control. Create the following files in `/etc/systemd/system/`.

**`docker-monitor.service`**

```ini
[Unit]
Description=Docker Container Monitor Service

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
Unit=docker-monitor.service

[Install]
WantedBy=timers.target
```

**Enable and Start:**

```bash
sudo systemctl enable --now docker-monitor.timer
```

### Option B: Cron Job Setup

Alternatively, use `cron` for a simpler setup. Edit your crontab with `crontab -e` and add the following line to run the script every 6 hours:

```crontab
0 */6 * * * /path/to/your/container-monitor.sh --no-update summary >/dev/null 2>&1
```

The redirection `>/dev/null 2>&1` prevents cron from sending emails for routine runs. The script's own file logging and notification systems will still function.

-----

## Intended Use Cases

This script is well-suited for the following environments:

  * **Home Labs and Self-Hosted Services**: For monitoring personal media servers, smart home setups, or development projects running on a single host.
  * **Small to Medium Deployments**: For monitoring a single server that runs a set of critical applications for a small business or project.
  * **Developer Workstations**: As a tool for quickly checking the health and status of a local development environment running in Docker.

## Limitations

It is important to understand the script's limitations to determine if it fits your needs.

  * **It is not a time-series monitoring system**: The script performs periodic checks and sends state-in-time alerts. It does not store historical data for creating graphs or dashboards, unlike systems such as Prometheus/Grafana.
  * **It is designed for single-host monitoring**: The script manages one host at a time. It is not designed for managing a large fleet of servers, where agent-based systems like Zabbix or Datadog would be more appropriate.
  * **It has external dependencies**: Its functionality requires that `docker`, `jq`, `skopeo`, and other standard Linux utilities are installed on the host system.
  * **Update checks are dependent on registry standards**: The version-update detection works best with repositories that use standard semantic versioning. It may be less effective with inconsistent or complex custom tagging schemes.
