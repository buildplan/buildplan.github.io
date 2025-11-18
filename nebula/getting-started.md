---
layout: default
title: Self-Hosted Nebula overlay VPN
nav_order: 14
parent: Home
last_modified_date: 2025-11-18T20:58:00+01:00
---

# Self-Hosted Nebula Overlay Network (Lighthouse on Docker)

Setting up a **Nebula overlay VPN** using a generic VPS (Debian 12) as the **Lighthouse**.

## 📖 Overview

**Nebula** is a scalable overlay networking tool originally developed by Slack. It enables you to seamlessly connect computers anywhere in the world into a single, encrypted, private network.

Unlike traditional VPNs that route all traffic through a central server (increasing latency), Nebula uses the Lighthouse only for **discovery**. Once nodes find each other, they form a direct **Peer-to-Peer (P2P)** encrypted tunnel.

**Architecture:**

* **Lighthouse:** A VPS running Nebula inside Docker.
* **Network Range:** `172.16.99.0/24` (Selected to avoid conflict with standard `192.168.x.x` LANs).
* **Security:** Certificate Authority (CA) keys are generated locally and **never** leave your trusted machine.

---

## 🛠 Prerequisites

1. **VPS:** A Debian 12 server with a static Public IP (Referred to as `YOUR_VPS_PUBLIC_IP`).
2. **Local Machine:** Linux, macOS, or WSL to generate keys.
3. **Software:**
    * **VPS:** Docker Engine & Docker Compose.
    * **Local:** `nebula-cert` binary.

### Download Nebula

Find the latest release for your architecture on the [Nebula Releases Page](https://github.com/slackhq/nebula/releases).

```bash
# Example: Downloading on Local Machine (Linux AMD64)
wget [https://github.com/slackhq/nebula/releases/download/v1.9.0/nebula-linux-amd64.tar.gz](https://github.com/slackhq/nebula/releases/download/v1.9.0/nebula-linux-amd64.tar.gz)
tar -xvf nebula-linux-amd64.tar.gz
# You now have 'nebula' and 'nebula-cert' binaries
```

---

## Phase 1: Certificate Authority (Local Machine)

**⚠️ SECURITY WARNING:** All steps in Phase 1 must be done on your local computer. Never generate the CA key on the VPS.

### 1. Create Workspace

```bash
mkdir -p ~/nebula-setup
cd ~/nebula-setup
```

### 2. Create the CA

The `-encrypt` flag ensures your master key is password-protected.

```bash
./nebula-cert ca -name "My Private Mesh" -encrypt
```

* **Output:** `ca.key` (KEEP SAFE/OFFLINE) and `ca.cert` (Public).

### 3. Generate Lighthouse Keys

We assign the Lighthouse the IP `172.16.99.1`.

```bash
./nebula-cert sign -name "lighthouse" -ip "172.16.99.1/24" -encrypt
```

* **Output:** `lighthouse.crt` and `lighthouse.key`.

---

## Phase 2: Configuration (Local Machine)

Create the necessary config files in your `~/nebula-setup` folder.

### 1. Lighthouse Config (`config.yaml`)

Create a file named `config.yaml`. Replace `YOUR_VPS_PUBLIC_IP` with your actual server IP.

```yaml
# ~/nebula-setup/config.yaml
pki:
  ca: /etc/nebula/ca.crt
  cert: /etc/nebula/host.crt
  key: /etc/nebula/host.key

static_host_map:
  # The Lighthouse defines its own physical address here so it knows what to advertise
  "172.16.99.1": ["YOUR_VPS_PUBLIC_IP:4242"]

lighthouse:
  am_lighthouse: true
  hosts:
    - "172.16.99.1"

listen:
  host: 0.0.0.0
  port: 4242

punchy:
  punch: true
  respond: true

firewall:
  outbound:
    - port: any
      proto: any
      host: any
  inbound:
    # Allow ICMP (Ping) for testing
    - port: any
      proto: icmp
      host: any
    # Allow Nebula traffic itself
    - port: any
      proto: any
      host: any
```

### 2. Docker Compose (`docker-compose.yml`)

```yaml
version: "3.8"
services:
  nebula:
    image: nebulaoss/nebula:latest
    container_name: nebula-lighthouse
    restart: unless-stopped
    # Host networking is highly recommended for Lighthouses
    network_mode: host
    cap_add:
      - NET_ADMIN
    volumes:
      - ./nebula-config:/etc/nebula
    command: ["-config", "/etc/nebula/config.yaml"]
```

---

## Phase 3: Deployment (VPS)

### 1. Prepare VPS Directory

SSH into your VPS and create the folder structure.

```bash
ssh user@YOUR_VPS_PUBLIC_IP
# On Remote:
sudo mkdir -p /opt/nebula/nebula-config
```

### 2. Upload Files

From your **Local Machine** `~/nebula-setup` folder:

```bash
# Copy Certificates (Renaming host certs to generic names)
scp ca.cert user@YOUR_VPS_PUBLIC_IP:/opt/nebula/nebula-config/ca.crt
scp lighthouse.crt user@YOUR_VPS_PUBLIC_IP:/opt/nebula/nebula-config/host.crt
scp lighthouse.key user@YOUR_VPS_PUBLIC_IP:/opt/nebula/nebula-config/host.key

# Copy Configs
scp config.yaml user@YOUR_VPS_PUBLIC_IP:/opt/nebula/nebula-config/config.yaml
scp docker-compose.yml user@YOUR_VPS_PUBLIC_IP:/opt/nebula/docker-compose.yml
```

### 3. Firewall & Start

On the **VPS**:

```bash
# Allow UDP Port 4242
sudo ufw allow 4242/udp comment 'Nebula Lighthouse'
sudo ufw reload

# Start Docker
cd /opt/nebula
sudo docker compose up -d
```

### 4. Verify

Check the logs to ensure the lighthouse is active:

```bash
sudo docker compose logs -f
```

---

## Phase 4: Adding Clients (e.g., Desktop/Laptop)

### 1. Generate Client Cert (Local Machine)

```bash
# Create a cert for a new host at .2
./nebula-cert sign -name "my-laptop" -ip "172.16.99.2/24" -encrypt
```

### 2. Copy Files to Client

Securely copy `ca.crt`, `my-laptop.crt`, and `my-laptop.key` to the client machine (e.g., `/etc/nebula/`).

### 3. Client Configuration

On the client, create a `config.yaml`. It is similar to the lighthouse config, but with these changes:

```yaml
lighthouse:
  am_lighthouse: false 
  hosts:
    - "172.16.99.1" # The Nebula IP of the Lighthouse

static_host_map:
  "172.16.99.1": ["YOUR_VPS_PUBLIC_IP:4242"]
```

### 4. Run as a Service (Systemd)

If your client is Linux, create a service file to run Nebula at boot.

**File:** `/etc/systemd/system/nebula.service`

```ini
[Unit]
Description=Nebula Overlay Network
Wants=basic.target
After=basic.target network.target

[Service]
SyslogIdentifier=nebula
StandardOutput=syslog
StandardError=syslog
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/local/bin/nebula -config /etc/nebula/config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable it:

```bash
sudo systemctl enable --now nebula
```

## Troubleshooting

* **Handshake Issues:** Ensure UDP port 4242 is open on the VPS firewall (UFW/AWS Security Group).
* **Time Sync:** Ensure both the VPS and Client clocks are synchronized.
* **Logs:** Always check `sudo docker compose logs` on the lighthouse for handshake errors.
