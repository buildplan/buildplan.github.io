---
permalink: /docs/container-monitor
title: "Docker Container Monitor"
description: "Bash script for monitoring Docker containers - checks health, resource usage, image updates, and sends notifications"
script_url: "https://buildplan.org/scripts/container-monitor.sh"
script_name: "container-monitor.sh"
github_raw_url: "https://raw.githubusercontent.com/buildplan/container-monitor/refs/heads/main/container-monitor.sh"
github_repo_url: "https://github.com/buildplan/container-monitor"
interactive: false
requires_sudo: false
no_pipe: true
requires_additional_files: true
additional_files:
  - name: "config.yml"
    url: "https://raw.githubusercontent.com/buildplan/container-monitor/refs/heads/main/config.yml"
    description: "Configuration file - customize monitoring thresholds, notifications, and container lists"
---