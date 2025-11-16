---
layout: default
title: Installation Scripts
nav_exclude: true
search_exclude: false
permalink: /scripts/
last_modified_date: 2025-11-16T15:20:58+01:00
---

# Quick Installation Scripts

Professional, ready-to-use installation scripts for various tools and configurations.

{: .warning }
> **Security Best Practice:** Always review scripts before running them. Each script page shows its full source code for transparency.

## Available Scripts

{% for script in site.scripts %}

### {{ script.title }}

{{ script.description }}

{% if script.requires_sudo %}

> <em><strong style="color: #f0ad4e;">Note:</strong> This script requires <code>sudo</code> privileges to run.</em>

{% endif %}

{% if script.interactive %}

> **Installation:** This script is **interactive** and cannot be piped.

{% else %}

{% if script.no_pipe %}

> **Installation:** This script **cannot be piped** for safety. Please download it first.

{% else %}

**Quick Install (One-Liner):**

```bash
curl -fsSL {{ script.script_url }} | sh
```

{% endif %}

[📖 View Details & Source]({{ script.url }}) • [📥 Download]({{ script.script_url }}) • [🔗 Repository]({{ script.github_repo_url }})

---

{% endfor %}

## Need Help?

Check out the [main documentation](/) for detailed guides and setup instructions.
