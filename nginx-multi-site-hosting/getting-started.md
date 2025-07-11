---
layout: default
title: A Secure, Automated, Multi-Site Hosting Environment
nav_order: 7
parent: Home
last_modified_date: 2025-07-11T22:50:27+01:00
---

### **Project Goal: A Secure, Automated, Multi-Site Hosting Environment**

This guide documents the end-to-end process of setting up a secure, multi-site hosting environment on a Debian 12 VPS. The journey begins with a simple reverse proxy setup and evolves into a sophisticated, automated pipeline that builds a custom, WAF-enabled version of Nginx Proxy Manager.

**Initial State:**

-   A Debian 12 VPS with key-based SSH access.
 
-   UFW firewall, Docker, and Tailscale VPN installed.
 
-   Website code hosted in a private Forgejo (Git) repository.
 
-   Domain DNS managed via Cloudflare.
 

### **Phase 1: Initial VPS & Website Setup**

The first phase focused on getting a single website online securely using a standard reverse proxy architecture.

#### **1.1. Preparing for Secure Code Deployment**

To avoid using personal SSH keys on the server, a read-only **deploy key** was created for the Git repository.

-   **On the VPS:** A new SSH key pair was generated specifically for deployment.
 
    ```
    ssh-keygen -t ed25519 -f ~/.ssh/forgejo_deploy_key
    ```
 
-   **In Forgejo:** The public key (`~/.ssh/forgejo_deploy_key.pub`) was added to the website's repository under **Settings > Deploy Keys**, with write access left unchecked.
 

#### **1.2. Setting Up the Reverse Proxy (Nginx Proxy Manager)**

We used Nginx Proxy Manager (NPM) to act as a reverse proxy, handling all incoming web traffic and directing it to the correct website container.

-   **Directory Structure:** A directory was created on the host at `/opt/npm`.
 
-   **Docker Compose:** The following `docker-compose.yml` was used to run NPM. The admin port (`81`) was intentionally bound to `127.0.0.1` to make it accessible only via the secure Tailscale VPN.
 
    ```
    # /opt/npm/docker-compose.yml
    services:
      npm:
        image: 'jc21/nginx-proxy-manager:latest'
        container_name: npm
        restart: unless-stopped
        ports:
          - '80:80/tcp'
          - '443:443/tcp'
          - '443:443/udp' # Added later for HTTP/3
          - '127.0.0.1:8181:81' # Admin panel
        volumes:
          - ./data:/data
          - ./letsencrypt:/etc/letsencrypt
    ```
 

#### **1.3. Firewall and DNS Configuration**

-   **UFW:** Ports 80 (HTTP) and 443 (HTTPS) were opened.
 
    ```
    sudo ufw allow 80/tcp
    sudo ufw allow 443/tcp
    sudo ufw reload
    ```
 
-   **Cloudflare:** An `A` record was created for the domain, pointing to the VPS's public IP address. The "Proxy status" was initially set to **DNS only (grey cloud)** to allow for direct SSL certificate validation by NPM.
 

#### **1.4. Deploying a Static Website Container**

Each website is deployed as its own Docker container, making it isolated and easy to manage.

1.  **Code:** The website code was cloned from Forgejo into `/opt/sites/my-simple-site`.
 
2.  **Dockerfile:** A simple `Dockerfile` was created inside the site's directory to serve the static files using Nginx.
 
    ```
    FROM nginx:stable-alpine
    COPY . /usr/share/nginx/html
    EXPOSE 80
    ```
 
3.  **Docker Compose:** A `docker-compose.yml` was created to build and run the site, connecting it to the same Docker network as NPM.
 
    ```
    # /opt/sites/my-simple-site/docker-compose.yml
    services:
      web:
        build: .
        container_name: my-simple-site
        restart: unless-stopped
        networks:
          - npm_default
    networks:
      npm_default:
        external: true
    ```
 
4.  **Linking in NPM:** Inside the NPM web UI (accessed via Tailscale), a Proxy Host was created.
 
    -   **Domain:** `www.example.com`
 
    -   **Forward Hostname:** `my-simple-site` (the container name)

    -   **Forward Port:** `80`
 
    -   **SSL:** A Let's Encrypt certificate was requested, and "Force SSL" was enabled.
 

### **Phase 2: Hardening the Setup**

With the site online, we layered on several security enhancements.

-   **Cloudflare:**
 
    -   The DNS record's proxy status was toggled to **Proxied (orange cloud)** to hide the server's IP and enable Cloudflare's protections.
 
    -   The SSL/TLS mode was set to **Full (Strict)** to ensure end-to-end encryption.
 
    -   The **Web Application Firewall (WAF)** was enabled to block common attacks.
 
-   **Nginx Proxy Manager:**
 
    -   **Security Headers** (like `Strict-Transport-Security`, `X-Frame-Options`, and `Content-Security-Policy`) were added via the "Advanced" tab of the proxy host to protect against browser-level attacks like clickjacking and XSS. This proved difficult and led to the final architecture.
 
-   **Host & Container Security:**
 
    -   **Fail2Ban** was installed on the host to protect the SSH port.
 
    -   **Unattended Upgrades** were enabled for automatic OS security patches.
 
    -   The website's `Dockerfile` was updated to run the Nginx process as a **non-root user**.
 
    -   **Log Rotation** was configured on the host using `logrotate` to manage the NPM log files and prevent disk space exhaustion.
 

### **Phase 3: Evolving to an Advanced Security Posture with CrowdSec**

To move beyond passive security and implement an active Intrusion Prevention System (IPS), CrowdSec was added to the stack. This phase involves two key components for layered protection.

#### **3.1. Setting up the CrowdSec Agent (in Docker)**

The CrowdSec Agent is the "brain" of the operation. It runs in a Docker container, reads logs from various sources, detects malicious behavior, and manages the blocklist.

-   **Implementation:** The `crowdsec` service was added to the main `docker-compose.yml` file, with volumes mounted to give it read-only access to the necessary host log files.
 

#### **3.2. Installing the Host Firewall Bouncer**

The Firewall Bouncer is the "shield." It's a service installed directly on the host OS that communicates with the CrowdSec agent and uses the system firewall (`iptables`) to block all traffic from banned IPs at the network level (Layer 3/4). This is the most efficient way to block attacks.

1.  **Add CrowdSec Repository:** First, add the official CrowdSec package repository to your Debian host.
 
    ```
    curl -s https://packagecloud.io/install/repositories/crowdsec/crowdsec/script.deb.sh | sudo bash
    ```
 
2.  **Install the Bouncer:** Update your package list and install the `iptables` version of the firewall bouncer.
 
    ```
    sudo apt update
    sudo apt install crowdsec-firewall-bouncer-iptables
    ```
 
3.  **Verify the Bouncer:** The bouncer should automatically detect the running CrowdSec agent (even in Docker) and register itself. You can verify this from your `docker-compose` directory:
 
    ```
    # From ~/sites/npm
    docker compose exec crowdsec cscli bouncers list
    ```
 
    You should see `host-firewall-bouncer` in the list with a valid status, confirming that your host's firewall is now actively protecting your server.
 

### **Phase 4: The Final Architecture - An Automated, WAF-Enabled Proxy**

The final goal was to integrate CrowdSec's application-level protection (AppSec/WAF) directly into the reverse proxy. This provides more granular control than the firewall bouncer, allowing for actions like presenting a CAPTCHA instead of a hard block.

#### **The Challenge & The Solution**

Initial attempts to install the CrowdSec Nginx Bouncer into the official NPM image failed due to fundamental incompatibilities.

The final, successful strategy was to **build a completely new, self-contained Docker image from scratch** that combines the best official components:

1.  **OpenResty:** A modern distribution of Nginx that comes with Lua support built-in.
 
2.  **Nginx Proxy Manager:** The official backend and frontend source code.
 
3.  **CrowdSec Lua Bouncer:** The official bouncer library.
 

#### **The Automation Pipeline (GitHub)**

A professional CI/CD pipeline was created in a GitHub repository (`buildplan/cs-ngx`) to automate the building and publishing of this custom image.

-   **The `Dockerfile`:** A multi-stage `Dockerfile` was engineered to build each component in its own clean environment and then copy only the finished artifacts into a minimal final image. This ensures the image is small, secure, and reproducible.
 
-   **The GitHub Actions Workflow:** A `build-and-push.yml` workflow was created to build the `Dockerfile` and publish the final image to GitHub Container Registry (GHCR) at `ghcr.io/buildplan/cs-ngx`.
 
-   **Dependabot:** A `dependabot.yml` file was added to automatically create pull requests when the base images (like `node` or `openresty`) have updates, ensuring the entire stack stays current.
 

#### **The Final Implementation on the VPS**

The setup on the VPS was simplified to use this new custom-built image.

1.  **Configuration Files:** Instead of a custom entrypoint, we adopted the official NPM method for customization.
 
    -   A bouncer config file (`~/sites/npm/crowdsec/bouncer.conf`) was created to hold the API key.
 
    -   An Nginx snippet (`~/sites/npm/custom/crowdsec.conf`) was created to activate the bouncer. NPM automatically loads any file placed in `/data/nginx/custom/http_top.conf` inside the container.
 
2.  **The Final `docker-compose.yml`:** The compose file was updated to use the new image from GHCR and mount the configuration files into the correct locations.
 
    ```
    # ~/sites/npm/docker-compose.yml
    services:
      npm:
        image: ghcr.io/buildplan/cs-ngx:latest
        container_name: npm-appsec
        pull_policy: always
        restart: unless-stopped
        ports:
          - "80:80"
          - "443:443"
          - "443:443/udp"
          - "127.0.0.1:8181:81"
        volumes:
          # Standard NPM data volumes
          - ./data:/data
          - ./letsencrypt:/etc/letsencrypt
          # Mount the bouncer config with the API key
          - ./crowdsec/bouncer.conf:/etc/crowdsec/bouncers/crowdsec-nginx-bouncer.conf:ro
          # Mount the Nginx snippet to activate the bouncer
          - ./custom/crowdsec.conf:/data/nginx/custom/http_top.conf:ro
    
      crowdsec:
        image: crowdsecurity/crowdsec:latest
        container_name: crowdsec
        restart: unless-stopped
        volumes:
          - ./crowdsec/config:/etc/crowdsec/
          - ./crowdsec/data:/var/lib/crowdsec/data/
          - /var/log:/var/log/host:ro # For host-level protection
        environment:
          - COLLECTIONS=crowdsecurity/linux crowdsecurity/sshd
          - TZ=Europe/London
          - GID=0
    ```


This final architecture represents a secure, modern, maintainable, and fully automated system for hosting multiple websites, complete with network-level and application-level intrusion prevention.
