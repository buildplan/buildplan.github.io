---
layout: default
title: caddy-plus - caddy reverse proxy with mods
nav_order: 17
parent: Home
last_modified_date: 2026-01-25T01:58:00+01:00
---

# caddy-plus

**caddy-plus** is a "battery-included" reverse proxy solution designed for Docker environments. It automates the complex task of securing and routing traffic to your containers.

This image integrates four core enterprise components into a single binary:

1. **[Caddy](https://caddyserver.com/)**: The modern, secure-by-default web server.
2. **[Caddy Docker Proxy](https://github.com/lucaslorentz/caddy-docker-proxy)**: Watcher that auto-generates Caddy configuration from Docker labels. You never need to edit a `Caddyfile` manually.
3. **[CrowdSec Bouncer](https://github.com/hslatman/caddy-crowdsec-bouncer)**: Built-in security that checks every visitor IP against a global cyber-threat blocklist. It also includes a Web Application Firewall (WAF) to block SQL injection and XSS.
4. **[Cloudflare DNS](https://github.com/caddy-dns/cloudflare)**: Enables DNS-01 challenges, allowing you to generate Wildcard Certificates and secure servers that aren't exposed to the public internet.

---

## Architecture

Understanding how the pieces fit together:

1. **Traffic Entry:** A user requests `app.yourdomain.com`.
2. **Cloudflare:** Resolves the IP (and hides your server IP if proxied via Orange Cloud).
3. **Caddy (The Gatekeeper):**

* **Trusts Cloudflare:** Restores the *real* visitor IP using the `caddy-cloudflare-ip` module.
* **Consults CrowdSec:** Asks the local CrowdSec agent: *"Is IP 1.2.3.4 a known threat?"*
* **Consults AppSec:** Scans the request body: *"Is there malicious code in this payload?"*

1. **Routing:** If safe, Caddy routes the traffic to the correct Docker container based on its labels.

---

## Prerequisites

Before running this stack, ensure you have:

1. **Docker & Docker Compose** installed.
2. **A Cloudflare Account** managing your domain's DNS.
3. **A Cloudflare API Token** with the permission `Zone:DNS:Edit` for all zones.

---

## Setup Guide

### Step 1: Create the External Network

We **must** create the Docker network manually.
*Why?* If we let Docker Compose create it, it prepends the folder name (e.g., `myfolder_caddy_net`). The proxy expects an exact name to find your containers.

```bash
docker network create caddy_net
```

### Step 2: Configure Cloudflare (The "Set & Forget" Method)

To avoid logging into Cloudflare every time you launch a new service, we use a **Wildcard A Record**.

1. Go to Cloudflare Dashboard > DNS.
2. Add an **A Record**:

* **Name:** `*` (Asterisk)
* **Content:** `YOUR_SERVER_IP`
* **Proxy Status:** Proxied (Orange Cloud)

1. Save.

**Result:** `any-name.yourdomain.com` now points to your server. Caddy will decide which ones to accept.

### Step 3: Prepare the Filesystem

CrowdSec needs to see Caddy's logs to detect attacks. We must create the log file before the container starts to ensure permissions are correct.

```bash
# Create directories for config and logs
mkdir -p caddy_logs crowdsec-config/acquis.d

# Create the empty log file
touch caddy_logs/access.log

# Grant read/write permissions so the container user can write to it
chmod 666 caddy_logs/access.log
```

### Step 4: Configure CrowdSec

We need to tell CrowdSec two things: "Read the Caddy logs" and "Turn on the WAF".

**A. Log Acquisition**
Create file: `./crowdsec-config/acquis.yaml`

```yaml
filenames:
  - /var/log/caddy/access.log
labels:
  type: caddy
```

**B. AppSec (WAF) Config**
Create file: `./crowdsec-config/acquis.d/appsec.yaml`

```yaml
listen_addr: 0.0.0.0:7422
appsec_config: crowdsecurity/appsec-default
name: caddy-appsec-listener
source: appsec
labels:
  type: appsec
```

### Step 5: Deploy the Stack

Create your `docker-compose.yml`.

> **Key Detail:** We use `labels` on the Caddy container to define **Global Settings** (like the CrowdSec API URL and Cloudflare Tokens). This keeps your configuration portable.

```yaml
services:
  caddy:
    image: ghcr.io/buildplan/caddy-plus:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
      - "443:443/udp" # Required for HTTP/3
    environment:
      # EXACT MATCH: Must match the external network name from Step 1
      - CADDY_INGRESS_NETWORKS=caddy_net
      # Cloudflare Token for DNS challenges & Real IP resolution
      - CF_API_TOKEN=your_cloudflare_token_here
    networks:
      - caddy_net
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock # REQUIRED: Lets Caddy see other containers
      - caddy_data:/data
      # Mount the shared log volume so CrowdSec can read it
      - ./caddy_logs:/var/log/caddy 
    
    # --- GLOBAL CONFIGURATION VIA LABELS ---
    labels:
      caddy.email: "you@example.com"
      
      # 1. Global Logging Configuration
      # Force Caddy to write logs to the shared file
      caddy.log.output: "file /var/log/caddy/access.log"
      caddy.log.format: "json"
      caddy.log.level: "INFO"
      
      # 2. CrowdSec Configuration
      # Connects Caddy to the CrowdSec Agent
      caddy.crowdsec.api_url: "http://crowdsec:8080"
      caddy.crowdsec.api_key: "YOUR_BOUNCER_KEY_HERE" # (See Step 6)
      caddy.crowdsec.appsec_url: "http://crowdsec:7422" 

      # 3. Cloudflare Trusted Proxies
      # Ensures Caddy sees the real visitor IP, not Cloudflare's
      caddy.servers.trusted_proxies: "cloudflare"

      # 4. Define Reusable Snippet: (cloudflare_tls)
      # Other containers can import this to get Wildcard/DNS certs
      caddy_0: "(cloudflare_tls)"
      caddy_0.tls.dns: "cloudflare {env.CF_API_TOKEN}"
      caddy_0.tls.resolvers: "1.1.1.1"

  crowdsec:
    image: crowdsecurity/crowdsec:latest
    container_name: crowdsec
    environment:
      # Required Collections: Caddy Logs + WAF Rules
      - COLLECTIONS=crowdsecurity/caddy crowdsecurity/appsec-virtual-patching crowdsecurity/appsec-generic-rules
      - CROWDSEC_LAPI_LISTEN_URI=0.0.0.0:8080
    networks:
      - caddy_net
    volumes:
      - ./crowdsec-db:/var/lib/crowdsec/data
      - ./crowdsec-config:/etc/crowdsec
      # Mount the acquisition configs created in Step 4
      - ./crowdsec-config/acquis.yaml:/etc/crowdsec/acquis.yaml
      - ./caddy_logs:/var/log/caddy

networks:
  caddy_net:
    external: true # Prevents Docker from renaming the network

volumes:
  caddy_data:
  crowdsec-db:
```

### Step 6: Generate & Add API Key

1. **Start the stack:**

```bash
docker compose up -d
```

1. **Generate a Key:**

```bash
docker exec crowdsec cscli bouncers add caddy-bouncer
```

1. **Update Compose:** Copy the key and paste it into the `caddy.crowdsec.api_key` label in your `docker-compose.yml`.
2. **Apply Changes:**

```bash
docker compose up -d
```

---

## Adding New Services

To deploy a new application protected by this stack, simply add it to the same network and use the following labels.

**Example: `whoami` service**

```yaml
services:
  whoami:
    image: traefik/whoami
    networks:
      - caddy_net
    labels:
      # 1. Domain Name (Wildcard DNS handles the routing!)
      caddy: "whoami.yourdomain.com"
      
      # 2. Use Cloudflare DNS Challenge
      # Imports the snippet we defined on the main Caddy container
      caddy.import: "cloudflare_tls"
      
      # 3. Enable Logging (CRITICAL for CrowdSec)
      # Without this, Caddy won't write logs for this site, and CrowdSec won't see attacks.
      caddy.log.output: "file /var/log/caddy/access.log"
      caddy.log.format: "json"
      
      # 4. Enable Security Layers
      # Order matters: 0=Block IP, 1=Check WAF, 2=Proxy
      caddy.route.0_crowdsec: "" 
      caddy.route.1_appsec: ""
      
      # 5. Security Headers (Optional but recommended)
      caddy.header.Strict-Transport-Security: "max-age=31536000; includeSubDomains"
      caddy.header.X-Frame-Options: "SAMEORIGIN"
      caddy.header.X-Content-Type-Options: "nosniff"
      
      # 6. Reverse Proxy
      # {{upstreams 80}} is a helper that automatically finds the container's IP
      caddy.route.2_reverse_proxy: "{{upstreams 80}}"

networks:
  caddy_net:
    external: true
```

---

## Troubleshooting

### 1. "Could not resolve host" / Browser Errors

* **Cause:** DNS Propagation delay.
* **Check:** Run `nslookup whoami.yourdomain.com 8.8.8.8`.
* *If it returns IPs:* The internet knows about your site. Your local computer's cache is just stale. Flush your DNS or wait 5 minutes.
* *If it fails:* Check your Cloudflare Wildcard `*` record.

### 2. "Container is not in same network as caddy"

* **Cause:** The service you are trying to proxy is not connected to `caddy_net`.
* **Fix:** Ensure your service has `networks: - caddy_net` and that `caddy_net` is defined as `external: true` at the bottom of the compose file.

### 3. "Connection Refused" in Caddy Logs

* **Log:** `dial tcp 172.x.x.x:8080: connect: connection refused`
* **Cause:** Caddy started faster than the CrowdSec container.
* **Fix:** Ignore it. Caddy has built-in retries and will connect automatically after 10-15 seconds once CrowdSec finishes loading its database.

### 4. Debugging the Config

Since the Caddyfile is generated in-memory, you cannot open a file to check it. Use this command to print the **active** configuration:

```bash
docker logs caddy 2>&1 | grep "New Caddyfile" | tail -n 1 | sed 's/.*"caddyfile":"//' | sed 's/"}$//' | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

```

### 5. Checking Security Status

Verify CrowdSec is active inside the Caddy container:

```bash
# Check connection health
docker exec caddy caddy crowdsec health

# Check if an IP is banned (simulated)
docker exec caddy caddy crowdsec check 1.2.3.4

```

---

## Included Plugins & Docs

* **[Caddy Docker Proxy](https://github.com/lucaslorentz/caddy-docker-proxy):** Dynamic configuration using Docker labels.
* **[CrowdSec Bouncer](https://github.com/hslatman/caddy-crowdsec-bouncer):** Security module for Caddy.
* **[Cloudflare DNS](https://github.com/caddy-dns/cloudflare):** DNS provider for solving ACME challenges.
* **[Cloudflare IP](https://github.com/WeidiDeng/caddy-cloudflare-ip):** Real visitor IP restoration when behind Cloudflare Proxy.
