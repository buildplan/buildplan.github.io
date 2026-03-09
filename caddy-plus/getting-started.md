---
layout: default
title: caddy-plus - caddy reverse proxy with mods
nav_order: 17
parent: Home
last_modified_date: 2026-03-09T18:58:00+01:00
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

## caddy-plus: Zero-to-Production Deployment Guide

A step-by-step guide to deploying the `caddy-plus` stack from scratch — from firewall hardening to a fully verified, protected application.

---

## Phase 1: Workspace & Server Preparation

First, create a dedicated project directory, secure the server, and set up the foundation for Docker to communicate.

### 1. Create the Working Directory

Keep all configuration and generated files organized in one place.

```bash
mkdir -p ~/caddy-plus && cd ~/caddy-plus
```

### 2. Secure the Server (CRITICAL)

Before touching the firewall, ensure you don't lock yourself out of your VPS. Allow SSH **first**, verify it is listed, and only then enable UFW.

```bash
# FIRST — before anything else
sudo ufw allow ssh          # or: sudo ufw allow 22/tcp
sudo ufw status             # verify SSH is listed BEFORE enabling

# Enable firewall safely (auto-disables after 30s if you lose SSH access)
sudo ufw enable; sleep 30; sudo ufw disable

# If your SSH session survived: re-enable permanently
sudo ufw enable

# Allow Cloudflare IPv4 & IPv6 to port 443
for ip in $(curl -s https://www.cloudflare.com/ips-v4); do sudo ufw allow from $ip to any port 443; done
for ip in $(curl -s https://www.cloudflare.com/ips-v6); do sudo ufw allow from $ip to any port 443; done
```

### 3. Configure Cloudflare DNS \& SSL

* **SSL Mode:** In your Cloudflare dashboard go to **SSL/TLS → Overview** and set the encryption mode to **Full (Strict)**. Any other mode causes infinite redirect loops.
* **Wildcard DNS:** Go to **DNS → Records** and add an `A` record: `Name = *`, `Content = <your-server-IP>`, **Proxied (Orange Cloud) ✅**.

This prevents you from manually creating a DNS record for every new service.

### 4. Create the External Docker Network

Caddy needs a guaranteed, prefix-free network name to auto-discover containers.

```bash
docker network create caddy_net
```

---

## Phase 2: Prepare Your Secrets

Hardcoding secrets in `docker-compose.yml` is a security risk. All sensitive values live in a `.env` file that Docker Compose reads automatically.

### 1. Generate Your Cloudflare API Token

In the Cloudflare dashboard: **My Profile → API Tokens → Create Token → Custom Token**. The token requires:

* **Permissions:** `Zone:DNS:Edit` and `Zone:Zone:Read`
* **Zone Resources:** Include your specific zone/domain only.

### 2. Create the `.env` File

```bash
touch .env
chmod 600 .env          # owner-readable only
echo ".env" >> .gitignore
```

### 3. Populate `.env`

Generate the OIDC cookie secret with:

```bash
python3 -c 'import os,base64; print(base64.urlsafe_b64encode(os.urandom(32)).decode())'
```

Then populate `.env`:

```env
CF_API_TOKEN=your_cloudflare_token_here
OAUTH2_PROXY_CLIENT_ID=your_client_id_here
OAUTH2_PROXY_CLIENT_SECRET=your_client_secret_here
OAUTH2_PROXY_COOKIE_SECRET=your_generated_cookie_secret_here
CROWDSEC_BOUNCER_KEY=YOUR_BOUNCER_KEY_HERE_FOR_LATER

# --- OPTIONAL: Uncomment if using Authentik and getting a 500 "Email not verified" error
# OAUTH2_PROXY_INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL=true
```

> Leave `CROWDSEC_BOUNCER_KEY` as a placeholder for now — it is generated in Phase 5.

---

## Phase 3: Directory & File Scaffolding

CrowdSec must read Caddy's logs, and the AppSec WAF engine requires its configuration files to exist **before** the containers start.

### 1. Create Directories and the Access Log File

```bash
mkdir -p caddy_logs crowdsec-db crowdsec-config/acquis.d
touch caddy_logs/access.log
chmod 666 caddy_logs/access.log
```

### 2. Configure CrowdSec Log Acquisition

Create `crowdsec-config/acquis.yaml`:

```yaml
filenames:
  - /var/log/caddy/access.log
labels:
  type: caddy
```

### 3. Enable the AppSec (WAF) Listener

Create `crowdsec-config/acquis.d/appsec.yaml`:

```yaml
listen_addr: 0.0.0.0:7422
appsec_config: crowdsecurity/appsec-default
name: caddy-appsec-listener
source: appsec
labels:
  type: appsec
```

---

## Phase 4: Core Stack Deployment

Create your master `docker-compose.yml` in `~/caddy-plus`. This file uses `depends_on` with a health check to guarantee CrowdSec is fully ready before Caddy attempts to connect to it.

```yaml
services:
  caddy:
    image: ghcr.io/buildplan/caddy-plus:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      # Port 80 omitted — DNS-01 challenges don't require it.
      # Add "- 80:80" only if you want HTTP → HTTPS redirects for non-Cloudflare traffic.
      - "443:443"
      - "443:443/udp"
    depends_on:
      crowdsec:
        condition: service_healthy
    environment:
      - CADDY_INGRESS_NETWORKS=caddy_net
      - CF_API_TOKEN=${CF_API_TOKEN}

      # OIDC Configuration
      - OAUTH2_PROXY_PROVIDER=oidc
      - OAUTH2_PROXY_OIDC_ISSUER_URL=https://auth.yourdomain.com/application/o/your-slug/
      - OAUTH2_PROXY_CLIENT_ID=${OAUTH2_PROXY_CLIENT_ID}
      - OAUTH2_PROXY_CLIENT_SECRET=${OAUTH2_PROXY_CLIENT_SECRET}
      - OAUTH2_PROXY_COOKIE_SECRET=${OAUTH2_PROXY_COOKIE_SECRET}
      # Authentik: Uncomment BOTH this line AND the matching line in .env if you get a 500 "Email not verified" error
      # - OAUTH2_PROXY_INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL=${OAUTH2_PROXY_INSECURE_OIDC_ALLOW_UNVERIFIED_EMAIL}
      - OAUTH2_PROXY_WHITELIST_DOMAINS=.yourdomain.com
      - OAUTH2_PROXY_COOKIE_DOMAINS=.yourdomain.com
      - OAUTH2_PROXY_EMAIL_DOMAINS=*
      - OAUTH2_PROXY_SKIP_PROVIDER_BUTTON=true
      - OAUTH2_PROXY_CODE_CHALLENGE_METHOD=S256

    networks:
      - caddy_net
    volumes:
      # WARNING: Grants Caddy full Docker API access.
      # Consider tecnativa/docker-socket-proxy for hardened environments.
      - /var/run/docker.sock:/var/run/docker.sock
      - caddy_data:/data
      - ./caddy_logs:/var/log/caddy

    labels:
      caddy.email: "admin@yourdomain.com"

      # Logging & Rotation
      # roll_size and roll_keep are children of output (nested label path)
      caddy.log.output: "file /var/log/caddy/access.log"
      caddy.log.output.roll_size: "100MiB"
      caddy.log.output.roll_keep: "5"
      caddy.log.format: "json"
      caddy.log.level: "INFO"

      # CrowdSec Global Settings
      caddy.crowdsec.api_url: "http://crowdsec:8080"
      caddy.crowdsec.api_key: "${CROWDSEC_BOUNCER_KEY}"
      caddy.crowdsec.appsec_url: "http://crowdsec:7422"
      caddy.servers.trusted_proxies: "cloudflare"

      # Reusable Snippet: (cloudflare_tls)
      # Import this in any service to get DNS-01 wildcard SSL certs
      caddy_0: "(cloudflare_tls)"
      caddy_0.tls.dns: "cloudflare {env.CF_API_TOKEN}"
      caddy_0.tls.resolvers: "1.1.1.1"

      # Reusable Snippet: (oidc)
      # Import this in any service to enforce SSO authentication
      caddy_1: "(oidc)"
      caddy_1.@protected: "not path /oauth2/*"
      caddy_1.forward_auth: "@protected localhost:4180"
      caddy_1.forward_auth.uri: "/oauth2/auth"
      caddy_1.forward_auth.header_up: "X-Real-IP {remote_host}"
      caddy_1.forward_auth.copy_headers: "X-Auth-Request-User X-Auth-Request-Email"
      caddy_1.forward_auth.0_@error: "status 401"
      caddy_1.forward_auth.0_handle_response: "@error"
      caddy_1.forward_auth.0_handle_response.0_redir: "* /oauth2/sign_in?rd={scheme}://{host}{uri}"
      caddy_1.handle: "/oauth2/*"
      caddy_1.handle.reverse_proxy: "localhost:4180"
      caddy_1.handle.reverse_proxy.header_up_0: "X-Real-IP {remote_host}"
      caddy_1.handle.reverse_proxy.header_up_1: "X-Forwarded-Uri {uri}"

  crowdsec:
    image: crowdsecurity/crowdsec:latest
    container_name: crowdsec
    environment:
      - COLLECTIONS=crowdsecurity/caddy crowdsecurity/appsec-virtual-patching crowdsecurity/appsec-generic-rules
      - CROWDSEC_LAPI_LISTEN_URI=0.0.0.0:8080
    healthcheck:
      test: ["CMD", "cscli", "lapi", "status"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s
    networks:
      - caddy_net
    volumes:
      - ./crowdsec-db:/var/lib/crowdsec/data
      - ./crowdsec-config:/etc/crowdsec
      - ./crowdsec-config/acquis.yaml:/etc/crowdsec/acquis.yaml
      - ./caddy_logs:/var/log/caddy

networks:
  caddy_net:
    external: true

volumes:
  caddy_data:
```

---

## Phase 5: Linking CrowdSec and Caddy

Caddy requires a Bouncer API key to query CrowdSec. We start CrowdSec in isolation, wait for it to be fully healthy, then generate the key.

### 1. Start CrowdSec Alone

```bash
docker compose up -d crowdsec
```

### 2. Wait Until CrowdSec Is Healthy

This blocks the terminal until the health check passes before you proceed.

```bash
until [ "$(docker inspect --format='{{.State.Health.Status}}' crowdsec)" = "healthy" ]; do sleep 3; done && echo "CrowdSec is ready"
```

### 3. Generate the Bouncer API Key

```bash
docker exec crowdsec cscli bouncers add caddy-bouncer
```

### 4. Update Your `.env` File

Copy the alphanumeric string output and replace `CROWDSEC_BOUNCER_KEY` in
your `.env` file.

> **Note on persistence:** This key is stored inside `./crowdsec-db`. The
> volume must be preserved across restarts. If you ever delete the volume, you
> must repeat this step to generate and register a new key.

### 5. Launch the Full Stack

```bash
docker compose up -d
```

---

## Phase 6: Deploying a Protected Application

With the infrastructure running, deploying a new protected service only requires attaching it to `caddy_net` with the correct labels.

### 1. Configure Your IdP Redirect URI

Before starting any new app, register its callback URL in your Identity
Provider (Authentik, PocketID, Google, etc.) or the OAuth2 flow will fail
with an "Invalid Redirect URI" error.

* **Redirect URI:** `https://app.yourdomain.com/oauth2/callback`
* **Authentik wildcard regex:** `^https://.*\.yourdomain\.com/oauth2/callback$`

### 2. Deploy the Application

Create a new directory and `docker-compose.yml` for your service. The `whoami` container below demonstrates the full security label pattern:

```yaml
services:
  whoami:
    image: traefik/whoami
    networks:
      - caddy_net
    labels:
      # Domain
      caddy: "app.yourdomain.com"

      # Import reusable snippets defined on the Caddy container
      caddy.import_0: "cloudflare_tls"   # DNS-01 wildcard SSL
      caddy.import_1: "oidc"             # SSO authentication

      # Required: write logs so CrowdSec can parse them
      caddy.log.output: "file /var/log/caddy/access.log"
      caddy.log.format: "json"

      # Security: IP blocking, WAF, and hardening headers
      caddy.route.0_crowdsec: ""
      caddy.route.1_appsec: ""
      caddy.header.Strict-Transport-Security: "max-age=31536000; includeSubDomains"
      caddy.header.X-Frame-Options: "SAMEORIGIN"
      caddy.header.X-Content-Type-Options: "nosniff"

      # Upstream (protected by everything above)
      caddy.route.2_reverse_proxy: "{{upstreams 80}}"

networks:
  caddy_net:
    external: true
```

```bash
docker compose up -d
```

Caddy will automatically detect the new container, provision a Cloudflare DNS-01 SSL certificate, enforce OIDC authentication, and route all traffic through the CrowdSec WAF.

---

## Phase 7: Verifying the Stack

Because `caddy-plus` runs multiple processes and generates its configuration dynamically, verification requires inspecting internals — not just the UI.

```bash
# 1. Check Supervisor process health (unique to this multi-process image)
docker exec caddy supervisorctl status
# Expected:
#   caddy        RUNNING   pid 7, uptime 0:05:00
#   oauth2-proxy RUNNING   pid 8, uptime 0:05:00

# 2. Verify CrowdSec is reading Caddy's logs
docker exec crowdsec cscli metrics
# Expected: Under "Acquisition Metrics":
#   file:/var/log/caddy/access.log | Lines read > 0

# 3. Verify the CrowdSec bouncer connection from Caddy's side
docker exec caddy caddy crowdsec health

# 4. Inspect the dynamically generated Caddyfile (essential for routing debug)
docker logs caddy 2>&1 | grep "New Caddyfile" | tail -n 1 \
  | sed 's/.*"caddyfile":"//' | sed 's/"}$//' \
  | sed 's/\\n/\n/g' | sed 's/\\t/\t/g'

# 5. Test end-to-end routing (expect 302 redirect to your IdP login page)
curl -I https://app.yourdomain.com
# Expected: HTTP/2 302
#           location: https://auth.yourdomain.com/...

# 6. (Optional) Check whether a specific IP is currently blocked by CrowdSec
docker exec caddy caddy crowdsec check 1.2.3.4
```

---

## Troubleshooting Reference

| Symptom | Cause | Fix |
| :-- | :-- | :-- |
| `502 Bad Gateway` | AppSec listener not running | Verify `acquis.d/appsec.yaml` exists and restart CrowdSec |
| Infinite redirect loop | Cloudflare SSL not set to Full (Strict) | Dashboard → SSL/TLS → Full (Strict) |
| `Invalid Redirect URI` | IdP callback not whitelisted | Add `https://app.yourdomain.com/oauth2/callback` to IdP |
| `oauth2-proxy` not RUNNING | Missing or malformed OIDC env vars | Check `.env` values and `docker compose logs caddy` |
| CrowdSec `Lines read: 0` | Log file path mismatch | Confirm `acquis.yaml` path matches Caddy's `log.output` label |
| Caddy won't start | CrowdSec not healthy yet | `depends_on` handles this; check `docker compose logs crowdsec` |

---

## Included Plugins & Docs

* **[Caddy Docker Proxy](https://github.com/lucaslorentz/caddy-docker-proxy):** Dynamic configuration using Docker labels.
* **[CrowdSec Bouncer](https://github.com/hslatman/caddy-crowdsec-bouncer):** Security module for Caddy.
* **[Cloudflare DNS](https://github.com/caddy-dns/cloudflare):** DNS provider for solving ACME challenges.
* **[Cloudflare IP](https://github.com/WeidiDeng/caddy-cloudflare-ip):** Real visitor IP restoration when behind Cloudflare Proxy.
