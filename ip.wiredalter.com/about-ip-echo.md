---
layout: default
title: Echo Service with Node.js and Docker
nav_order: 15
parent: Home
last_modified_date: 2025-12-22T20:58:00+01:00
---

# Building a Hybrid IP Echo Service with Node.js and Docker

**Live Service:** [ip.wiredalter.com](https://ip.wiredalter.com)

For basic network testing, standard IP echo services (like `ifconfig.me`, `ip.me`) are great, These services typically return a simple text string of public IP. But as I started integrating network, I found myself needing more than just an IP address. I needed context.

I wanted to know: *Where is this traffic coming from? Who owns the network? Is this a residential connection or a potential proxy/VPN?*

This project was born out of that need. I built **WiredAlter IP Intelligence**, a self-hosted microservice that provides deep geolocation and risk analysis data.

Here is a technical walkthrough of how I built it using Node.js, Docker, and a hybrid database approach to solve the problem of accurate VPN detection.

---

## The Goal:

The requirement was to build a single service that could serve three different types of users:

1. **Humans (Browser):** A clean UI with visual badges and a privacy-conscious map.
2. **Scripts (JSON):** A rich API response including City, ASN, Timezone, and Proxy status.
3. **Terminal Users (CLI):** A quick, readable text summary for when I'm working in SSH.

## Architecture & Tech Stack

The core service is built on **Node.js (v24)**, using **Express** for routing and **rate-limiting** to prevent abuse. To ensure portability and easy deployment, the entire application is containerized with **Docker**.

### The Dual-Database Approach

The biggest challenge in building an IP service is data accuracy. No single free database gives the complete picture. To get the best of both worlds, I implemented a **Dual-Database Architecture**:

1. **Location & ISP:** I use [MaxMind GeoLite2](https://dev.maxmind.com/geoip/geolite2-free-geolocation-data) (City & ASN databases). In my testing, MaxMind offered the most reliable data for physical location (City/Country) and Organization names.
2. **Threat Intelligence:** I integrated [IP2Location LITE (PX11)](https://lite.ip2location.com/). This database specializes in classifying IPs by "Usage Type" (e.g., Residential vs. Data Center) and assigning Threat scores.

## The Challenge: When Databases Lag

During development, I encountered a common problem: **Data Lag**.
New VPN servers spin up every day. A static database might take weeks to flag a new DigitalOcean droplet or M247 server as a "Proxy."

This created contradictory outputs where the ISP name was obviously a hosting provider (e.g., "M247 Ltd"), but the database still classified it as a "Standard ISP."

### The Solution: Hybrid Consistency Logic

To fix this, I added a **Consistency Override** layer into the Node.js backend. This logic acts as a final "sanity check" before sending the response:

1. **Database Lookup:** First, query MaxMind and IP2Location for the raw data.
2. **Keyword Analysis:** Scan the ISP/Organization string against a custom list of known hosting providers (e.g., `DigitalOcean`, `Hetzner`, `M247`, `Vultr`, `Linode`).
3. **Forced Override:** If a keyword matches, the system **forces** the `is_proxy` flag to `true` and updates the usage type to "Datacenter / VPN," overriding the static database.

This ensures that obvious server-grade IPs are flagged immediately, even if the database update hasn't arrived yet.

## How to Use the Service

This service has a flexible API. You can access the data in three ways depending on your needs.

### 1. The Terminal (CLI)

For a quick health check or to verify your VPN connection from a terminal, use these commands:

| Goal | Command | Output Format |
| --- | --- | --- |
| **Simple IP** | `curl ip.wiredalter.com` | Just the IP string (e.g., `192.168.1.1`). Perfect for variables in scripts. |
| **Visual Summary** | `curl ip.wiredalter.com/cli` | A ASCII table showing Location, ISP, ASN, and Risk Status. |
| **Full JSON** | `curl ip.wiredalter.com/json` | The complete raw data object. |

**Example Output (`/cli`):**

```text
 ----------------------------------------
  WIREDALTER IP INTELLIGENCE
 ----------------------------------------
  IP         : 146.70.179.xx
  Location   : Canary Wharf, United Kingdom
  Organization: M247 Europe SRL
  ASN        : AS9009

  Connection : Datacenter
  Risk Status: Datacenter / VPN
  Threat     : High (Keyword Match)
 ----------------------------------------

```

### 2. The Web Interface

Visiting [ip.wiredalter.com](https://ip.wiredalter.com) in a browser loads the dashboard.

* **Smart Badges:** Instantly see if your connection is "Verified" (Residential) or "Risk" (VPN/Datacenter).
* **Map:** A privacy-focused map rendered with **Leaflet.js** and **OpenStreetMap** shows the approximate location of the IP.

### 3. The API (`/json`)

For developers, the JSON endpoint provides granular details. Here is the data structure available for your applications:

```json
{
  "ip": "2a01:4b00:xxxx:xxxx",
  "country": "United Kingdom",
  "city": "London",
  "region": "England",
  "timezone": "Europe/London",
  "coordinates": "51.5074, -0.1278",
  "asn": "AS56478",
  "org": "Hyperoptic Ltd",
  "is_proxy": false,
  "proxy_type": "No",
  "usage_type": "Standard ISP",
  "threat": "None",
  "provider": "N/A"
}

```

## Automation & Maintenance

Static databases are only good if they are fresh. To avoid manual maintenance, I automated the update process using shell scripts.

* **Cron Job:** Three separate scripts runs automatically, twice weekly for MaxMind Databases and a daily script for IP2location Database (aligning with the IP2Location LITE release cycle).
* **Updates:** These scripts download the new databases, verify these and only restarts the Node.js service if the file has actually changed, preventing downtime or corruption from failed downloads.

## Credits & Acknowledgments

It wouldn't be possible to build this service without these open tools and data sources:

* **Runtime:** [Node.js](https://nodejs.org/) & [Express](https://expressjs.com/)
* **Location Data:** [MaxMind GeoLite2](https://dev.maxmind.com/geoip/geolite2-free-geolocation-data)
* **Proxy Data:** [IP2Location LITE](https://lite.ip2location.com/)
* **Maps:** [Leaflet.js](https://leafletjs.com/) & [OpenStreetMap](https://www.openstreetmap.org/)

---

*Feel free to use the service for your own testing at [ip.wiredalter.com](https://ip.wiredalter.com).*