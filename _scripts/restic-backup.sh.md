---
permalink: /docs/restic-backup
title: "Restic Backup Script"
description: "Automated encrypted backups with restic - supports local and remote repositories, scheduling, notifications, and safe restore workflows"
script_url: "https://raw.githubusercontent.com/buildplan/restic-backup-script/refs/heads/main/restic-backup.sh"
script_name: "restic-backup.sh"
github_raw_url: "https://raw.githubusercontent.com/buildplan/restic-backup-script/refs/heads/main/restic-backup.sh"
github_repo_url: "https://github.com/buildplan/restic-backup-script"
interactive: true
requires_sudo: true
no_pipe: true
requires_additional_files: true
additional_files:
  - name: "restic-backup.conf"
    url: "https://raw.githubusercontent.com/buildplan/restic-backup-script/refs/heads/main/restic-backup.conf"
    description: "Main configuration file"
  - name: "restic-excludes.txt"
    url: "https://raw.githubusercontent.com/buildplan/restic-backup-script/refs/heads/main/restic-excludes.txt"
    description: "File exclusion patterns"
---
