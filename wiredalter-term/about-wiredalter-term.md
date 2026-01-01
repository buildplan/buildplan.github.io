---
layout: default
title: A containerized, web-based terminal interface
nav_order: 16
parent: Home
last_modified_date: 2026-01-01T13:58:00+01:00
---

# WiredAlter-Term

**Repository:** [https://github.com/buildplan/WiredAlter-Term](https://github.com/buildplan/WiredAlter-Term)

## Project Overview

WiredAlter-Term is a containerized, web-based terminal interface designed to provide a persistent, portable, and customizable command-line environment accessible via a browser. Built on **Node.js 24** and **Debian 13 (Trixie)**, it leverages `xterm.js` and `node-pty` for terminal emulation while maintaining a persistent backend state.

The core design philosophy emphasizes **portability** (running on any host without permission conflicts) and **persistence** (separating user configuration from the ephemeral container runtime).

## System Architecture

### 1. The "Seed and Link" Persistence Strategy

To resolve the conflict between ephemeral container filesystems and the need for persistent user configurations (dotfiles), the application employs a custom "Seed and Link" logic during startup (`src/index.js`):

1. **Detection:** The application checks a mounted host volume (`/data`) for existing configuration files.
2. **Seeding:** If specific files (e.g., `.bashrc`, `starship.toml`) are missing from the volume, the application copies "Factory Defaults" (baked into the container image at `/usr/local/share/smart-term`) to the volume.
3. **Linking:** The application forcefully removes the container's local configuration directories and replaces them with symbolic links pointing to the `/data` volume.

This ensures that user customizations survive container restarts, while the system remains self-healing if configuration files are corrupted or deleted.

### 2. Dynamic Permission Mapping

To enable Docker-in-Docker control without privilege escalation issues, the entrypoint script (`src/entrypoint.sh`) dynamically detects the Group ID (GID) of the host’s Docker socket (`/var/run/docker.sock`). It creates a corresponding group inside the container and adds the `node` user to it at runtime, ensuring seamless communication with the host Docker daemon.

### 3. Security Layer

The application implements a custom authentication middleware using:

* **Express-Session & FileStore:** Sessions are persisted to disk (`/data/sessions`), preventing user logout during container restarts.
* **Rate Limiting:** A brute-force protection mechanism locks out login attempts for 15 minutes after 5 failed PIN entries.
* **Asset Whitelisting:** Static assets (CSS, Fonts, JS) are served via a whitelist to ensure the login page remains accessible while protecting the socket connection.

---

## Installation & Deployment

### Prerequisites

* Docker and Docker Compose installed on the host machine.
* (Optional) A reverse proxy (Nginx/Traefik/Cloudflare Tunnel) if exposing to the public internet.

### Quick Start

1. **Clone the Repository:**

```bash
git clone https://github.com/buildplan/WiredAlter-Term.git
cd WiredAlter-Term
```

2. **Deploy via Docker Compose:**
The default configuration exposes the terminal on port `3939`.

```bash
docker compose up -d --build
```

3. **Access:**
Navigate to `http://localhost:3939` (or your server IP).
* **Default PIN:** `123456` (Change this immediately in production).

---

## Configuration

Configuration is managed via Environment Variables in `docker-compose.yml`.

| Variable | Default | Description |
| --- | --- | --- |
| `PIN` | `123456` | The numeric passcode required to access the terminal. |
| `SESSION_SECRET` | *(Default string)* | A random string used to sign session cookies. **Must be changed.** |
| `PORT` | `3939` | The internal port the Node.js application listens on. |
| `NODE_ENV` | `production` | Set to `production` for performance optimization. |

### Example `docker-compose.yml`

```yaml
services:
  wiredalter-term:
    build: .
    image: wiredalter-term
    container_name: wiredalter-term
    restart: unless-stopped
    ports:
      - "3939:3939"
    volumes:
      # Persistent storage for configs, keys, and history
      - ./data:/data
      # Socket mapping for Docker-in-Docker control
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - PIN=882299
      - SESSION_SECRET=ChangeThisToARandomString123!
      - NODE_ENV=production
```

---

## Data Persistence & Storage

All persistent data is stored in the `./data` directory on the host machine. The container symlinks internal paths to this directory.

| Feature | Container Path | Host Path | Notes |
| --- | --- | --- | --- |
| **General Storage** | `~/storage` | `./data/storage` | Use this folder for persistent downloads/scripts. |
| **SSH Keys** | `~/.ssh` | `./data/.ssh` | Keys generated here persist across rebuilds. |
| **Shell Config** | `~/.bashrc` | `./data/.bashrc` | Stores aliases and env vars. |
| **Shell History** | `~/.bash_history` | `./data/.bash_history` | Preserves command history. |
| **Prompt Config** | `~/.config/` | `./data/.config/` | Stores `starship.toml`. |
| **Fonts** | *(Internal)* | `./data/fonts/` | Holds the `.ttf` file served to the frontend. |

---

## Customization Guide

### 1. Changing the Font

The terminal uses a Nerd Font to render icons correctly. To change the font (e.g., to FiraCode or JetBrains Mono):

1. Download a **Nerd Font** compatible `.ttf` file.
2. Rename the file to `font.ttf`.
3. Replace the existing file at `./data/fonts/font.ttf` on the host.
4. Perform a "Hard Refresh" in the browser (`Ctrl+F5`) to clear the font cache.

### 2. Customizing the Prompt

The prompt is powered by [Starship](https://starship.rs).

1. Locate `./data/.config/starship.toml` on the host.
2. Edit the file to modify colors, symbols, or module behavior.
3. Restart the container (`docker compose restart`) or reload the shell to apply changes.

### 3. Factory Reset

If configuration files become corrupted or usability is lost:

1. Stop the container: `docker compose down`.
2. Delete the specific configuration file from the host's `./data` directory (e.g., `rm data/.config/starship.toml`).
3. Start the container: `docker compose up -d`.
4. The system will detect the missing file and auto-restore the factory default version.

---

## Troubleshooting

### "Docker permission denied" inside the terminal

**Cause:** The container cannot access the host's Docker socket due to a Group ID mismatch.
**Solution:** Ensure `/var/run/docker.sock` is mounted in `docker-compose.yml`. Check container logs (`docker logs wiredalter-term`) to confirm the entrypoint script successfully detected the GID:

> `🔌 Detected Host Docker GID: 999`

### Changes to `starship.toml` keep reverting

**Cause:** Starship defaults to a built-in preset if it detects a syntax error in the configuration file.
**Solution:**

1. Run `cat ~/.config/starship.toml` inside the terminal to verify your changes exist on disk.
2. If the file exists but the prompt looks like the default, check the file for syntax errors (missing quotes, unclosed brackets).

### `npm install` fails during local development

**Cause:** The `node-pty` dependency requires C++ compilation tools (`python3`, `make`, `g++`) which may not be present on the host machine.
**Solution:** Do not run `npm install` on the host. Allow the `Dockerfile` to handle installation during the build process, as it includes the necessary build toolchain.
