---
layout: default
title: Self-Hosted Nebula overlay VPN
nav_order: 14
parent: Home
last_modified_date: 2025-11-18T20:58:00+01:00
---

# Nebula Overlay Network on a VPS (Lighthouse + Docker Compose)

## Overview

Nebula is a scalable, encrypted overlay network that connects hosts over a virtual subnet (for example $172.16.99.0/24$) while traffic flows directly between peers whenever possible.

Unlike traditional VPNs that push all traffic through a central server, Nebula uses **lighthouses** only to help peers find each other; once connected, hosts communicate via direct, mutually authenticated tunnels using Noise, ECDH, and AES‑256‑GCM.

Each host has a certificate signed by a private **CA** that encodes its Nebula IP, name, and optional groups, letting you build firewall rules similar to cloud security groups (for example “only laptops in the admin group can SSH to servers”).

This guide assumes:

- A **Debian 12 VPS** with public IP as lighthouse, running Nebula in Docker with `network_mode: host`.
- A Nebula subnet `172.16.99.0/24` that does not overlap with your normal LANs (`192.168.x.x`, `10.x.x.x`, `172.16–31.x.x`).

---

## Prerequisites

You will need the following components before starting:

- **Lighthouse VPS**
  - Debian 12 (or similar), with a public IPv4 (or IPv6) address $YOUR\_VPS\_PUBLIC\_IP$.
  - SSH access as a user with `sudo`.
  - Docker Engine and Docker Compose installed.
- **Local machine (CA + tooling)**
  - Linux, macOS, or WSL.
  - `nebula` and `nebula-cert` binaries from the official GitHub **releases** page.
- **Optional client hosts**
  - Linux desktops, laptops, or other servers where you can run Nebula as a binary or service.

Nebula can also run on Windows, macOS, mobile, and as a system package (Debian/Ubuntu/Fedora/Arch), but this document focuses on a Dockerized lighthouse and generic Linux clients.

---

## Download Nebula Binaries (Local)

On your **local** machine, download the current Nebula release (adjust version and architecture as needed):

```bash
mkdir -p ~/nebula-setup
cd ~/nebula-setup

# Example for Linux amd64 – replace v1.9.7 with latest
wget https://github.com/slackhq/nebula/releases/download/v1.9.7/nebula-linux-amd64.tar.gz
tar -xvf nebula-linux-amd64.tar.gz

# You now have ./nebula and ./nebula-cert in this directory
```

Using the official release ensures you get the latest bug fixes and protocol improvements.

---

## Phase 1 – Create CA and Lighthouse Certificates (Local Only)

All PKI operations should be performed on your **local** machine, and the CA private key must never be stored on the VPS or any untrusted node.

### 1. Create a workspace

```bash
mkdir -p ~/nebula-setup
cd ~/nebula-setup
# Ensure ./nebula-cert is present or in your PATH
```

This directory will hold the CA key/cert, host certs, and config templates.

### 2. Create the Certificate Authority (CA)

```bash
./nebula-cert ca -name "My Private Mesh" -encrypt
```

- `-name` is a label for your Nebula network or organization.
- `-encrypt` password‑protects `ca.key` at rest using AES‑256‑GCM and Argon2id.

This generates:

- `ca.key` – encrypted CA private key; keep this offline, backed up, and never copy it to any Nebula host.
- `ca.cert` – CA public certificate; copied to every host.

By default, the CA lifetime is one year; you can specify a longer or shorter duration using `-duration`.

### 3. Create lighthouse host certificate

Assign the lighthouse the first address in your Nebula subnet, for example `172.16.99.1/24`.

```bash
./nebula-cert sign \
  -name "lighthouse" \
  -ip "172.16.99.1/24" \
  -encrypt
```

This produces `lighthouse.crt` and `lighthouse.key`, with the private key encrypted on disk.

You can also add groups like `"lighthouse,servers"` if you plan to use group‑based firewall rules later.

---

## Phase 2 – Lighthouse Config and Docker Compose (Local)

Now create the configuration and Docker Compose file on your **local** machine.

### 1. Lighthouse Nebula config (`config.yaml`)

Create `~/nebula-setup/config.yaml`, substituting your real VPS public IP or DNS for `YOUR_VPS_PUBLIC_IP`.

```yaml
# ~/nebula-setup/config.yaml

pki:
  ca: /etc/nebula/ca.crt
  cert: /etc/nebula/host.crt
  key: /etc/nebula/host.key

static_host_map:
  # Lighthouse Nebula IP -> public IP:port
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

# Optional TUN settings if you need to tweak MTU or interface name
# tun:
#   dev: nebula1
#   mtu: 1300

logging:
  level: info
  format: text

firewall:
  conntrack:
    tcp_timeout: 120h
    udp_timeout: 3m
    default_timeout: 10m
    max_connections: 100000

  outbound:
    - port: any
      proto: any
      host: any

  inbound:
    # Allow ICMP for testing
    - port: any
      proto: icmp
      host: any

    # Example: allow SSH to the lighthouse only from "admin" group in future
    # - port: 22
    #   proto: tcp
    #   group: admin
```

Key points:

- `am_lighthouse: true` marks this node as a discovery node.
- `listen.port: 4242` must be fixed and reachable on the public Internet.
- `static_host_map` lets other hosts find the lighthouse by mapping Nebula IP to public address.

### 2. Docker Compose for lighthouse (`docker-compose.yml`)

Create `~/nebula-setup/docker-compose.yml`:

```yaml
# ~/nebula-setup/docker-compose.yml
version: "3.8"

services:
  nebula:
    image: nebulaoss/nebula:latest
    container_name: nebula-lighthouse
    restart: unless-stopped

    # Host networking so Nebula can create the tun interface in the host namespace
    network_mode: host

    cap_add:
      - NET_ADMIN

    volumes:
      - ./nebula-config:/etc/nebula

    command: ["-config", "/etc/nebula/config.yaml"]
```

Notes:

- `nebulaoss/nebula` is the official Docker image.
- `network_mode: host` is required to expose the `nebula1` TUN interface to the host.
- `NET_ADMIN` is needed for TUN/TAP operations.

---

## Phase 3 – Deploy the Lighthouse on the VPS

Now push the files to the VPS and run the Dockerized Nebula lighthouse.

### 1. Prepare the directory layout on VPS

SSH into the lighthouse VPS:

```bash
ssh user@YOUR_VPS_PUBLIC_IP

# On the VPS:
sudo mkdir -p /opt/nebula/nebula-config
cd /opt/nebula
```

Using `/opt/nebula` keeps the Docker deployment separate from other local Nebula installs that may use `/etc/nebula`.

### 2. Copy config and certs from local to VPS

From your **local machine** in `~/nebula-setup`:

```bash
# CA public cert
scp ca.cert user@YOUR_VPS_PUBLIC_IP:/opt/nebula/nebula-config/ca.crt

# Lighthouse cert/key (renamed to generic host names used by config.yaml)
scp lighthouse.crt user@YOUR_VPS_PUBLIC_IP:/opt/nebula/nebula-config/host.crt
scp lighthouse.key user@YOUR_VPS_PUBLIC_IP:/opt/nebula/nebula-config/host.key

# Config and docker-compose.yml
scp config.yaml user@YOUR_VPS_PUBLIC_IP:/opt/nebula/nebula-config/config.yaml
scp docker-compose.yml user@YOUR_VPS_PUBLIC_IP:/opt/nebula/docker-compose.yml
```

Do **not** copy `ca.key` to the VPS or any other host; this is explicitly warned against in the official quick‑start.

### 3. Open Nebula UDP port in the VPS firewall

On the VPS, ensure UDP/4242 is allowed in any host or cloud firewall:

```bash
sudo ufw allow 4242/udp comment 'Nebula Lighthouse'
sudo ufw reload
sudo ufw status verbose
```

If you use iptables, firewalld, or cloud provider rules, allow UDP/4242 to the VPS as well.

### 4. Start Nebula with Docker Compose

On the VPS:

```bash
cd /opt/nebula
sudo docker compose up -d
```

This starts the `nebula-lighthouse` container and should create the `nebula1` interface on the host.

### 5. Verify lighthouse is running

On the VPS:

```bash
cd /opt/nebula

# Check Nebula logs
sudo docker compose logs -f
```

Look for log lines showing the config loaded, listening on `0.0.0.0:4242`, and successful TUN device creation.

Then confirm the TUN interface and IP assignment:

```bash
ip addr show nebula1
```

You should see `inet 172.16.99.1/24` on `nebula1`; test local reachability:

```bash
ping 172.16.99.1
```

Successful ping indicates the Nebula interface is up and responding on the lighthouse host itself.

---

## Phase 4 – Add Linux Client Hosts

For each additional host (desktop, laptop, or VPS), the workflow is: generate a host cert on your local machine, create a client config, copy files, run Nebula, and test connectivity.

### 1. Generate certificate for a new host (local)

On your **local** machine in `~/nebula-setup`:

```bash
./nebula-cert sign \
  -name "my-laptop" \
  -ip "172.16.99.2/24" \
  -groups "desktops,admin" \
  -encrypt
```

- Choose a unique Nebula IP in `172.16.99.0/24` for each host.
- `-groups` is optional but recommended if you want fine‑grained firewall policies later.

This produces `my-laptop.crt` and `my-laptop.key` on your local machine.

### 2. Create client Nebula config

Create `config-my-laptop.yaml` locally or on the destination host; adjust the name as needed:

```yaml
# Example non-lighthouse client config

pki:
  ca: /etc/nebula/ca.crt
  cert: /etc/nebula/host.crt
  key: /etc/nebula/host.key

static_host_map:
  # Lighthouse: Nebula IP -> public IP:Port
  "172.16.99.1": ["YOUR_VPS_PUBLIC_IP:4242"]

lighthouse:
  am_lighthouse: false
  interval: 60
  hosts:
    - "172.16.99.1"

listen:
  host: 0.0.0.0
  port: 0   # Let Nebula choose a random UDP port

punchy:
  punch: true
  respond: true

logging:
  level: info
  format: text

firewall:
  outbound:
    - port: any
      proto: any
      host: any

  inbound:
    # Allow ICMP for testing
    - port: any
      proto: icmp
      host: any

    # Example: SSH only from "admin" group
    # - port: 22
    #   proto: tcp
    #   group: admin
```

Important differences compared to the lighthouse:

- `am_lighthouse: false` – this is a regular client.
- `listen.port: 0` – Nebula chooses an available UDP port (recommended for roaming clients).

### 3. Copy certs and config to the client host

From your **local** machine:

```bash
scp ca.cert my-laptop.crt my-laptop.key \
    config-my-laptop.yaml \
    user@MY_LAPTOP_HOST:/tmp/
```

On the client host:

```bash
sudo mkdir -p /etc/nebula
cd /tmp

sudo mv config-my-laptop.yaml /etc/nebula/config.yaml
sudo mv ca.cert /etc/nebula/ca.crt
sudo mv my-laptop.crt /etc/nebula/host.crt
sudo mv my-laptop.key /etc/nebula/host.key
```

Again, never copy `ca.key` – only the CA certificate and per‑host cert/key are required.

### 4. Install and run Nebula on the client

You can either install Nebula from a distribution package or use the binary downloaded from GitHub releases.

Example using a locally installed binary at `/usr/local/bin/nebula`:

```bash
sudo /usr/local/bin/nebula -config /etc/nebula/config.yaml
```

To run Nebula automatically on boot using systemd, create `/etc/systemd/system/nebula.service`:

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

Then enable and start it:

```bash
sudo systemctl enable --now nebula
```

Make sure any host firewall allows outbound UDP to `YOUR_VPS_PUBLIC_IP:4242`, or more restrictively allows that specific destination if egress is locked down.

### 5. Verify overlay connectivity

From the new client host:

```bash
ping 172.16.99.1
```

From the lighthouse VPS:

```bash
ping 172.16.99.2
```

You should be able to ping between Nebula IPs, and higher‑level services (for example SSH on `172.16.99.x`) will work once firewall rules permit them.

If you want to test from inside the container itself:

```bash
sudo docker exec -it nebula-lighthouse /bin/sh
ping 172.16.99.2
```

---

## Expanding the Network

Adding more nodes follows exactly the same pattern: sign a cert, create a config, copy files, start Nebula, test ping.

- Use a new IP for each host in `172.16.99.0/24` (`.3`, `.4`, and so on).
- Keep `static_host_map` and `lighthouse.hosts` pointing at the lighthouse Nebula and public IP.
- For redundancy, create additional lighthouses and list all of them in `lighthouse.hosts` and `static_host_map` for every host.

You can also add non‑Linux clients using the same certificates and configuration schema, using platform‑specific installation methods (for example Homebrew on macOS, MSI or manual service on Windows, and mobile apps).

---

## Security and Maintenance Notes

A few operational practices help keep your Nebula network robust and secure:

- **Protect the CA key**: `ca.key` is the root of trust; keep it encrypted and offline, ideally in a password manager or secure vault.
- **Encrypt host keys**: Using `-encrypt` with `nebula-cert sign` protects host private keys at rest.
- **Track certificate lifetimes**: The default CA and host durations can be customized; plan a rotation before expiry using the rotation guidance in the Nebula docs.
- **Firewall hardening**: Start with permissive firewall rules while testing, then restrict `inbound` rules to specific ports, groups, and hosts once you know the flows you need.
- **MTU and path issues**: If you see fragmentation or odd connectivity issues, consider setting `tun.mtu` to a slightly smaller value (for example 1300) across all hosts.

---

## Nebula Official Docs and GitHub

Docs: [https://nebula.defined.net/docs/](https://nebula.defined.net/docs/)  
GitHub: [https://github.com/slackhq/nebula](https://github.com/slackhq/nebula)
