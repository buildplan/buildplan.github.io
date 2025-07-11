---
layout: default
title: cs-caddy
nav_order: 2
parent: Home
last_modified_date: 2025-07-11T23:05:27+01:00
---

# cs-caddy: Project Documentation

This document provides a comprehensive guide to building, deploying, and configuring a custom Caddy web server image integrated with the CrowdSec Security Engine. It covers the automated build pipeline using GitHub Actions and the local deployment using Docker Compose.

## 1\. Project Overview

The goal of this project is to create a Caddy Docker image with a built-in CrowdSec bouncer. This provides two primary layers of security directly at the web server level, before traffic reaches your applications:

1.  **IP Address Blocking:** Utilizes CrowdSec's community blocklist and local security engine decisions to block known malicious IP addresses.
    
2.  **Web Application Firewall (WAF):** The AppSec component inspects web requests for malicious patterns like SQL injection, XSS, and attempts to exploit known vulnerabilities (CVEs), providing an essential layer of application security.
    

The project uses an automated CI/CD pipeline with GitHub Actions to build and publish the image, ensuring it stays up-to-date with the latest versions of Caddy and the CrowdSec bouncer.

## 2\. The Automated Build Pipeline (GitHub)

This setup uses three key files to create a fully automated build and release pipeline.

### The `caddy.Dockerfile`

This file defines the steps to build the custom Caddy binary. It uses a multi-stage build to keep the final image small and secure.

**Key Features:**

-   **Stage 1 (Builder):** Uses a `golang` base image to compile Caddy with the necessary CrowdSec bouncer modules (`http`, `layer4`, `appsec`).
    
-   **Stage 2 (Final Image):** Uses the official `caddy:latest` image as a base and copies the custom-built binary from the builder stage. This ensures the final image has all the correct underlying dependencies.
    

```
# caddy.Dockerfile

# Stage 1: Build custom Caddy with CrowdSec bouncer
FROM golang:1.24-alpine AS builder

RUN apk add --no-cache git

WORKDIR /app

# Create a main.go file that imports Caddy and all the desired plugins
RUN tee main.go <<EOF
package main

import (
    caddycmd "[github.com/caddyserver/caddy/v2/cmd](https://github.com/caddyserver/caddy/v2/cmd)"

    _ "[github.com/caddyserver/caddy/v2/modules/standard](https://github.com/caddyserver/caddy/v2/modules/standard)"
    _ "[github.com/hslatman/caddy-crowdsec-bouncer/appsec](https://github.com/hslatman/caddy-crowdsec-bouncer/appsec)"
    _ "[github.com/hslatman/caddy-crowdsec-bouncer/http](https://github.com/hslatman/caddy-crowdsec-bouncer/http)"
    _ "[github.com/hslatman/caddy-crowdsec-bouncer/layer4](https://github.com/hslatman/caddy-crowdsec-bouncer/layer4)"
)

func main() {
    caddycmd.Main()
}
EOF

# Initialize a Go module and download all the necessary dependencies
RUN go mod init custom-caddy && go mod tidy

# Build CS-Caddy binary
RUN CGO_ENABLED=0 GOOS=linux go build \
    -o /usr/bin/caddy \
    -ldflags "-w -s" .

# Final stage: Use upstream Caddy base image
FROM caddy:latest

# Copy CS-Caddy binary from the builder stage
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
```

### GitHub Actions Workflows

This project uses an intelligent, event-driven approach with three workflow files located in the `.github/workflows/` directory.

#### a) `check-caddy-release.yml` & `check-bouncer-release.yml` (The Checkers)

These two files are nearly identical. Their only job is to periodically check the official GitHub repositories for Caddy and the `caddy-crowdsec-bouncer` for new releases.

-   **How they work:** They run on a schedule (e.g., daily). They fetch the latest release tag and use it as a key for `actions/cache`. If the key is new (meaning a new release has been published), the cache action misses. This triggers the final step, which uses `peter-evans/repository-dispatch` to send an event (e.g., `caddy-release`) back to our own repository.
    

#### b) `build-and-push.yml` (The Builder)

This is the main workflow that does all the heavy lifting. It is designed to be triggered by events, not its own schedule, making it highly efficient.

-   **Triggers:** It runs when:
    
    -   A `repository_dispatch` event is received from one of the "checker" workflows.
        
    -   Code is pushed to the `main` branch.
        
    -   It is triggered manually via the GitHub UI.
        
-   **Process:**
    
    1.  Fetches the latest version numbers for Caddy and the bouncer.
        
    2.  Sets up QEMU and Docker Buildx for multi-arch builds (`linux/amd64`, `linux/arm64`).
        
    3.  Logs into both GitHub Container Registry (GHCR) and Docker Hub using secrets.
        
    4.  Builds the `caddy.Dockerfile`.
        
    5.  Pushes the image to both registries with a comprehensive set of tags (`latest`, version-specific, etc.).
        
    6.  Creates a formal GitHub Release on the repository to document the new build.
        

### Setting Up Secrets

For the workflow to push to Docker Hub, you must add your credentials as encrypted secrets in your GitHub repository.

1.  Go to your repository **Settings** > **Secrets and variables** > **Actions**.
    
2.  Create a secret named `DOCKERHUB_USERNAME` with your Docker Hub username.
    
3.  Create a secret named `DOCKERHUB_TOKEN` with a Docker Hub [Access Token](https://hub.docker.com/settings/security "null").
    

The `secrets.GITHUB_TOKEN` is provided automatically by GitHub Actions and does not need to be created manually.

## 3\. Local Deployment Guide

This section explains how to use the custom Caddy image in a local Docker Compose setup.

### Step 1: `docker-compose.yml` Structure

Your `docker-compose.yml` should define at least two services: `caddy` and `crowdsec`. They must be on the same Docker network to communicate.

```
# docker-compose.yml
version: '3.8'

services:
  caddy:
    # Use the custom image you built
    image: ghcr.io/buildplan/cs-caddy:latest
    container_name: caddy
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    networks:
      - your-network-name
    volumes:
      # Mount your Caddyfile and a directory for Caddy's logs
      - ./caddy/Caddyfile:/etc/caddy/Caddyfile:ro
      - ./caddy/logs:/var/log/caddy
      # Persist Caddy's internal data (like certificates)
      - caddy_data:/data
      - caddy_config:/config

  crowdsec:
    image: crowdsecurity/crowdsec:latest
    container_name: crowdsec
    restart: unless-stopped
    networks:
      - your-network-name
    volumes:
      # Mount the Caddy log file for acquisition
      - ./caddy/logs/access.log:/var/log/caddy/access.log:ro
      # Mount the entire CrowdSec config directory
      - ./crowdsec/config:/etc/crowdsec
      # Persist the CrowdSec database
      - crowdsec_db:/var/lib/crowdsec/data

volumes:
  caddy_data:
  caddy_config:
  crowdsec_db:

networks:
  your-network-name:
```

### Step 2: Configure CrowdSec for AppSec

To enable the Web Application Firewall (WAF), you need to tell your CrowdSec agent to activate its AppSec component.

1.  **Install the necessary collections:**
    
    ```
    docker compose exec crowdsec cscli collections install crowdsecurity/appsec-virtual-patching
    docker compose exec crowdsec cscli collections install crowdsecurity/appsec-generic-rules
    ```
    
2.  **Create the AppSec acquisition file:** Inside the local directory you mounted to `/etc/crowdsec` (e.g., `./crowdsec/config/`), create a new directory `acquis.d` and place a file named `appsec.yaml` inside it.
    
    **File path:** `./crowdsec/config/acquis.d/appsec.yaml` **Content:**
    
    ```
    listen_addr: 0.0.0.0:7422
    appsec_config: crowdsecurity/appsec-default
    name: caddy-appsec-listener
    source: appsec
    labels:
      type: appsec
    ```
    

### Step 3: Configure the `Caddyfile`

This is the final piece. Your `Caddyfile` tells Caddy how to handle requests, where to send them, and how to apply security.

1.  **Generate a Bouncer API Key:**
    
    ```
    docker compose exec crowdsec cscli bouncers add caddy-bouncer
    ```
    
    Copy the generated key.
    
2.  **Create your `Caddyfile`:**
    
    ```
    # ./caddy/Caddyfile
    
    # --- Global Options Block ---
    {
        # Define logging once, globally, to avoid parsing errors.
        log {
            output file /var/log/caddy/access.log {
                roll_size 10mb
                roll_keep 5
            }
            format json
            level INFO
        }
    
        # --- CrowdSec Configuration ---
        crowdsec {
            # Point to the CrowdSec container using its service name
            api_url http://crowdsec:8080
            api_key <your_crowdsec_api_key_goes_here>
    
            # Point to the AppSec component running inside CrowdSec
            appsec_url http://crowdsec:7422
        }
    }
    
    # --- Example Site Block ---
    your-domain.com {
        # Use a route block to ensure security runs first
        route {
            # Apply IP blocking and WAF protection
            crowdsec
            appsec
    
            # Your application logic comes after security
            reverse_proxy your-app-container:8000
        }
    }
    ```
    

### Step 4: Launch and Verify

After setting up all the files, launch the stack:

```
docker compose up -d
```

To verify that everything is working, run:

```
docker compose exec crowdsec cscli metrics
```

Look for the **"Acquisition Metrics"** table to ensure Caddy logs are being parsed, and the **"Appsec Metrics"** table to confirm the WAF is processing requests.
