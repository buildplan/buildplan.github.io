---
layout: default
title: cs-caddy
nav_order: 2
parent: Home
---

# cs-caddy

A custom Docker image for the Caddy web server that includes the CrowdSec bouncer for IP blocking and a Web Application Firewall (WAF).

This makes it easy to add two layers of security directly into your web server. It's based on the excellent [caddy-crowdsec-bouncer](https://github.com/hslatman/caddy-crowdsec-bouncer) by hslatman.

The image is automatically rebuilt and updated on GHCR whenever there is a new release of Caddy, so there'll always be latest version whenever caddy or caddy-crowdsec-bouncer has an update.

## How It Works

This setup gives two types of protection:

1.  **IP Blocker (`crowdsec`):** Acts like a front-desk security guard. It checks the IP address of every visitor against CrowdSec's blocklist and denies entry to known troublemakers.
2.  **Web Application Firewall / WAF (`appsec`):** Acts like a security team inside the building. It inspects the *actions* of every visitor, blocking malicious requests like SQL injection, path traversal, and attempts to exploit known software vulnerabilities (CVEs).

## How to Use This Image

Follow these steps to integrate this Caddy image into your own Docker-based setup.

### Step 1: Use the Custom Image in Docker Compose

In your `docker-compose.yml` file, use the image `ghcr.io/buildplan/cs-caddy:latest` for your Caddy service. Make sure Caddy is on the same Docker network as your CrowdSec container.

```yaml
# docker-compose.yml

services:
  caddy:
    # Use the custom image from this repository
    image: ghcr.io/buildplan/cs-caddy:latest
    pull_policy: always # Recommended to get updates
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    networks:
      - your-network-name # Must be the same network as CrowdSec
    volumes:
      - ./Caddyfile:/etc/caddy/Caddyfile
      - ./caddy_logs:/var/log/caddy # For Caddy's own logs
      # ... other volumes ...

  crowdsec:
    # ... your crowdsec service definition ...
    networks:
      - your-network-name

# ... other services and network definitions ...
```
Step 2: Get a Bouncer API KeyYour Caddy bouncer needs a key to talk to the CrowdSec agent. Generate one by running:docker compose exec `crowdsec cscli bouncers add caddy-bouncer`
Copy the API key that it gives you.

Step 3: Enable AppSec in CrowdSecFor the WAF to work, you need to tell your CrowdSec agent to enable the AppSec component.Install the AppSec rule collections:
```
docker compose exec crowdsec cscli collections install crowdsecurity/appsec-virtual-patching
docker compose exec crowdsec cscli collections install crowdsecurity/appsec-generic-rules
```
Create an AppSec acquisition file: This file tells CrowdSec to activate the AppSec engine. Create a file named appsec.yaml inside the local directory that you mount to /etc/crowdsec in your container. For example, if you mount ./crowdsec/config:/etc/crowdsec, then create the file at `./crowdsec/config/acquis.d/appsec.yaml.acquis.d/appsec.yaml`:
```
listen_addr: 0.0.0.0:7422
appsec_config: crowdsecurity/appsec-default
name: caddy-appsec-listener
source: appsec
labels:
  type: appsec
```

Step 4: Configure Your CaddyfileNow, edit your Caddyfile to use the bouncer.Add the main crowdsec configuration to your global options block at the top.Add the crowdsec and appsec directives inside a route block for every site you want to protect.Here is an example:

```
# Caddyfile

# --- Global Options ---
{
    # Define logging once, globally.
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
		api_url http://crowdsec:8080
		api_key <your_crowdsec_api_key_goes_here>
		appsec_url http://crowdsec:7422
	}
}

# --- Example Site ---
your-domain.com {
    # Use a route block to control the order of directives
	route {
        # Security directives should come first
		crowdsec
		appsec

        # Your other directives, like reverse_proxy
		reverse_proxy your-app-container:8000
	}
}
```

Step 5: Restart and VerifyYou're all set. Restart your entire stack to apply all the changes:docker compose up -d --force-recreate
To check that everything is working, run docker compose exec crowdsec cscli metrics. You should see a table named "Appsec Metrics", which confirms the WAF is active and processing requests.Included UtilitiesWhen Caddy is built with this module, a new caddy crowdsec command is available. This is useful for checking the status of your integration directly.$ docker compose exec caddy caddy crowdsec

```
# Example: check if an IP is banned
$ docker compose exec caddy caddy crowdsec check 1.2.3.4
```

```
# options below are taken from https://github.com/hslatman/caddy-crowdsec-bouncer
$ docker exec caddy crowdsec ...

Commands related to the CrowdSec integration (experimental)

Usage:
  caddy crowdsec [command]

Available Commands:
  check       Checks an IP to be banned or not
  health      Checks CrowdSec integration health
  info        Shows CrowdSec runtime information
  ping        Pings the CrowdSec LAPI endpoint

Flags:
  -a, --adapter string   Name of config adapter to apply (when --config is used)
      --address string   The address to use to reach the admin API endpoint, if not the default
  -c, --config string    Configuration file to use to parse the admin address, if --address is not used
  -h, --help             help for crowdsec
  -v, --version          version for crowdsec

Use "caddy crowdsec [command] --help" for more information about a command.

Full documentation is available at:
https://caddyserver.com/docs/command-line
```
