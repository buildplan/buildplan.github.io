---
layout: default
title: Self-Hosted Firefox Sync Server
nav_order: 13
parent: Home
last_modified_date: 2025-10-28T20:58:00+01:00
---

# Self-Hosted Firefox Sync Server Setup

## 🚀 Overview

This guide details how to set up a self-hosted Firefox Sync server using the `syncstorage-rs` Rust implementation, MariaDB, and Docker Compose.

This method **only stores your sync data** (bookmarks, passwords, history, etc.) on your server. Authentication is still handled by Mozilla's Firefox Accounts (FxA) service, which is the recommended and most secure approach.

## 📋 Prerequisites

- A server or VPS with **Docker** and **Docker Compose** installed.
- A **domain name** (e.g., `sync.yourdomain.com`) with DNS records pointing to your server's IP.
- A **reverse proxy** (like Nginx, Traefik, Caddy, or Pangolin) to handle HTTPS.
- A valid **SSL certificate** (e.g., from Let's Encrypt) configured in your reverse proxy.

-----

## 🛠️ Installation Steps

### 1. Clone the Repository

```bash
cd ~
git clone https://github.com/dan-r/syncstorage-rs-docker.git
cd syncstorage-rs-docker
```

### 2. Create and Populate Environment File

Copy the example file, then generate your secrets.

```bash
cp example.env .env
```

Now, run these commands to generate the necessary secrets. **Copy the output** of each command.

```bash
# Generate random passwords for MariaDB
echo "MYSQL_ROOT_PASSWORD=$(openssl rand -base64 32)"
echo "MYSQL_PASSWORD=$(openssl rand -base64 32)"

# Generate 64-character secrets (as recommended by the repo)
echo "SYNC_MASTER_SECRET=$(cat /dev/urandom | base32 | head -c64)"
echo "METRICS_HASH_SECRET=$(cat /dev/urandom | base32 | head -c64)"
```

Now, edit the `.env` file and paste those values in, along with your domain.

```bash
nano .env
```

Your `.env` file should look like this:

```bash
# Your public-facing URL with SSL
SYNC_URL=https://sync.yourdomain.com

# --- Paste your generated secrets below ---
MYSQL_ROOT_PASSWORD=...REDACTED_ROOT_PASSWORD...
MYSQL_PASSWORD=...REDACTED_SYNC_PASSWORD...
SYNC_MASTER_SECRET=...REDACTED_MASTER_SECRET...
METRICS_HASH_SECRET=...REDACTED_METRICS_SECRET...

# (Optional) Limit the number of users
SYNC_CAPACITY=10
```

### 3. Use Pre-Built Docker Image

This is the recommended approach. Edit `docker-compose.yaml` to ensure you are not building from source.

```bash
nano docker-compose.yaml
```

Change the `firefox-syncserver` service **from** this:

```
firefox-syncserver:
  build:
    context: ./app
    dockerfile: Dockerfile
```

**To** this (using the pre-built image):

```
firefox-syncserver:
  image: ghcr.io/dan-r/syncstorage-rs-docker:main
```

### 4. Add Logging Configuration (Optional, Recommended)

To prevent logs from consuming all your disk space, add a `logging` section to both services in `docker-compose.yaml`.

**Complete docker-compose.yaml should look like this:**

```
services:
  firefox-mariadb:
    container_name: firefox-mariadb
    image: linuxserver/mariadb:11.4.8
    volumes:
      - ./data/config:/config
      - ./data/initdb.d/init.sql:/config/initdb.d/init.sql
    restart: unless-stopped
    environment:
      MYSQL_DATABASE: syncstorage
      MYSQL_USER: sync
      MYSQL_PASSWORD: ${MYSQL_PASSWORD}
      MYSQL_ROOT_PASSWORD: ${MYSQL_ROOT_PASSWORD}
    logging:
      driver: "json-file"
      options: { max-size: "5m", max-file: "3" }

  firefox-syncserver:
    container_name: firefox-syncserver
    image: ghcr.io/dan-r/syncstorage-rs-docker:main
    restart: unless-stopped
    ports:
      - "8000:8000"
    depends_on:
      - firefox-mariadb
    environment:
      LOGLEVEL: info
      SYNC_URL: ${SYNC_URL}
      SYNC_CAPACITY: 10
      SYNC_MASTER_SECRET: ${SYNC_MASTER_SECRET}
      METRICS_HASH_SECRET: ${METRICS_HASH_SECRET}
      SYNC_SYNCSTORAGE_DATABASE_URL: mysql://sync:${MYSQL_PASSWORD}@firefox-mariadb:3306/syncstorage_rs
      SYNC_TOKENSERVER_DATABASE_URL: mysql://sync:${MYSQL_PASSWORD}@firefox-mariadb:3306/tokenserver_rs
    logging:
      driver: "json-file"
      options: { max-size: "5m", max-file: "3" }
```

### 5. Verify Database Init Script

Ensure the script that creates the databases exists.

```bash
cat data/initdb.d/init.sql
```

It should contain:

```SQL
CREATE DATABASE IF NOT EXISTS syncstorage_rs;
CREATE DATABASE IF NOT EXISTS tokenserver_rs;
GRANT ALL PRIVILEGES ON syncstorage_rs.* TO 'sync'@'%';
GRANT ALL PRIVILEGES ON tokenserver_rs.* TO 'sync'@'%';
FLUSH PRIVILEGES;
```

### 6. Start the Containers

Launch the services in detached mode.

```bash
docker compose up -d
```

Monitor the logs to ensure both containers start correctly.

```bash
docker compose logs -f
```

Wait until you see:

- `firefox-mariadb` | `[ls.io-init] done.`
- `firefox-syncserver` | `Server running on http://0.0.0.0:8000`

-----

## 🔄 Reverse Proxy Configuration

Your sync server is running on `http://localhost:8000`. You **must** expose it securely over HTTPS (port 443).

### Using Nginx

This is a secure, production-ready config.

```
# Define rate limiting zone
limit_req_zone $binary_remote_addr zone=sync:10m rate=10r/s;

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name sync.yourdomain.com;

    # SSL Config
    ssl_certificate /path/to/fullchain.pem;
    ssl_certificate_key /path/to/privkey.pem;
    
    # Security Headers
    add_header X-Content-Type-Options nosniff always;
    add_header X-Frame-Options DENY always;
    add_header X-XSS-Protection "1; mode=block" always;

    location / {
        # Apply rate limiting
        limit_req zone=sync burst=20 nodelay;

        proxy_pass http://127.0.0.1:8000; 
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_http_version 1.1;
    }
}
```

### Using Pangolin

1.  Access Pangolin UI.
2.  Create a **Site**:
    - **Domain:** `sync.yourdomain.com`
    - Enable **SSL/TLS**.
3.  Create a **Resource**:
    - **Type:** `HTTP`
    - **Target:** `firefox-syncserver:8000` (if on the same Docker network as newt or Pangolin on same VPS) or `http://localhost:8000`.        
    - **CRITICAL:** Do **NOT** enable any authentication (OIDC, Basic Auth, etc.).
4.  Add **Security Headers** & **Rate Limiting** **Geo-blocking** as needed.

-----

### 🦊 Firefox Client Configuration

This is the most important step.

#### Desktop (Firefox / Zen / Waterfox / Librewolf)

1.  Open a new tab and go to `about:config`. Accept the warning.
2.  In the search bar, type: `identity.sync.tokenserver.uri`
3.  Click the **Edit** (pencil) icon and set the value to:

    `https://sync.yourdomain.com/1.0/sync/1.5`

    > **Note:** This is the correct URL for this setup. It does *not* contain the `/token/` prefix.

4.  Go to **Settings** → **Firefox Account**.
5.  Click **Sign Out** and confirm.
6.  **Sign back in** with the *same* Firefox Account.

#### Mobile (Android)

1.  Install Firefox.
2.  Go to **Settings** → **About Firefox**.
3.  Tap the Firefox logo 5 times to unlock developer options.
4.  Go back to **Settings** → **Sync Debug**.
5.  Enter your URL: `https://sync.yourdomain.com/1.0/sync/1.5`
6.  Sign into your Firefox Account.

### Mobile (iOS)

**Not supported.** Firefox for iOS does not allow changing the sync server.

-----

### ✅ Verification and Testing

1.  **Check Server Health**

    - Visit `https://sync.yourdomain.com/__heartbeat__` in your browser.
    - **Expected:** `{"status": "Ok", ...}`

2.  **Monitor Logs**

    - `cd ~/syncstorage-rs-docker`
    - `docker compose logs -f firefox-syncserver`
    - After signing in, you should see activity:

        - `{"token_type":"OAuth","uid":"..."}` (Successful authentication)
        - `{"uri.path":"/1.5/.../storage/bookmarks","uri.method":"POST"}` (Syncing data)

3.  **Verify Database**

    - Get your `sync` user's password: `grep MYSQL_PASSWORD .env | cut -d'=' -f2`
    - Check for registered users:

        ```bash
        docker exec firefox-mariadb mariadb -u sync -p$(grep MYSQL_PASSWORD .env | cut -d'=' -f2) -e "SELECT * FROM tokenserver_rs.users;"
        ```

    - Check for synced items (BSOs - "Binary Storage Objects"):

        ```bash
        docker exec firefox-mariadb mariadb -u sync -p$(grep MYSQL_PASSWORD .env | cut -d'=' -f2) -e "SELECT COUNT(*) as total_items FROM syncstorage_rs.bso;"
        ```
 
4.  **Force Manual Sync**

    - On Desktop: **Settings** → **Sync** → Click **"Sync now"**.

-----

### 📈 What Success Looks Like

After you've signed into Firefox on one or two devices, here's how you know it's working perfectly:

- **In Firefox:** Go to **Settings** \$\\rightarrow\$ **Sync**. It should show "Sync: On" and "Last synced: just now" (or a few moments ago).
- **In the Server Logs:** You'll see `OAuth` authentications followed by `POST` requests to paths like `/1.5/.../storage/bookmarks`, `/storage/passwords`, etc.
- **In the Database:** After the initial sync, running this command should show a significant number of items (e.g., 1000+ for an established profile).

    ```bash
    docker exec firefox-mariadb mariadb -u sync -p$(grep MYSQL_PASSWORD .env | cut -d'=' -f2) -e "SELECT COUNT(*) FROM syncstorage_rs.bso;"
    ```

-----

## 🚑 Troubleshooting

- **Issue: 502 "Bad Gateway" Error**

    - **Cause:** Reverse proxy can't reach the `firefox-syncserver` container.
    - **Fix:** Check `docker compose ps` and `docker compose logs firefox-syncserver`. Test with `curl http://localhost:8000/__heartbeat__` on the server itself.

- **Issue: No Sync Activity in Logs**

    - **Cause:** The `about:config` value is incorrect or you didn't sign out/in.
    - **Fix:**

        1.  Verify `identity.sync.tokenserver.uri` is exactly `https://sync.yourdomain.com/1.0/sync/1.5`.
        2.  Ensure you have **Signed Out** and **Signed Back In** to Firefox. This is required to force the client to re-read the new server setting.

- **Issue: Database Connection Errors**

    - **Cause:** `firefox-syncserver` started before `firefox-mariadb` was ready.
    - **Fix:** Check `docker compose logs firefox-mariadb` and wait for `[ls.io-init] done.`. Then restart the stack: `docker compose restart`.

- **Issue: `collections` Table Shows 0 Bytes**

    - **This is normal.** This table is for metadata. The *actual* data is stored in the `bso` table. Check its count instead (see verification step).

-----

## 🔧 Maintenance & Quick Commands

- **Backup**

    ```bash
    # Backup environment file (CRITICAL)
    cp ~/syncstorage-rs-docker/.env ~/firefox-sync-backup.env
    
    # Backup database
    docker exec firefox-mariadb mysqldump -u sync -p$(grep MYSQL_PASSWORD .env | cut -d'=' -f2) --all-databases > ~/firefox-sync-backup.sql
    ```

- **Update**

    ```bash
    cd ~/syncstorage-rs-docker
    docker compose pull
    docker compose up -d
    docker image prune
    ```

- **View Logs**

    ```bash
    docker compose logs -f firefox-syncserver
    ```

- **Stop / Start**

    ```bash
    docker compose down
    docker compose up -d
    ```

- **Check Item Count**

    ```bash
    docker exec firefox-mariadb mariadb -u sync -p$(grep MYSQL_PASSWORD .env | cut -d'=' -f2) -e "SELECT COUNT(*) FROM syncstorage_rs.bso;"
    ```

- **Full Uninstall**

    ```bash
    cd ~/syncstorage-rs-docker
    docker compose down -v  # -v removes the persistent database volume
    cd ~
    rm -rf ~/syncstorage-rs-docker
    ```
