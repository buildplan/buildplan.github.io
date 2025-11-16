---
permalink: /docs/rsync-backup
title: "Rsync Backup Script"
description: "This script automates backups of local directories to a remote server (such as a Hetzner Storage Box) using rsync over SSH."
script_url: "https://buildplan.org/scripts/backup_script.sh"
script_name: "restic-backup.sh"
github_raw_url: "https://raw.githubusercontent.com/buildplan/rsync-backup-script/refs/heads/main/backup_script.sh"
github_repo_url: "https://github.com/buildplan/rsync-backup-script"
interactive: true
requires_additional_files: true
additional_files:
  - name: "backup.conf"
    url: "https://raw.githubusercontent.com/buildplan/rsync-backup-script/refs/heads/main/backup.conf"
    description: "Main configuration file for files to backup, notifications and exculde settings"
---
