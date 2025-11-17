---
layout: default
title: Installation Scripts
nav_exclude: true
search_exclude: false
permalink: /scripts/
last_modified_date: 2025-11-16T15:20:58+01:00
---

# Quick Installation Scripts

Scripts for various tools and configurations.

{: .warning }
> **Security Best Practice:**
> Always review scripts before running them. Each script page shows its full source code for transparency.

## Available Scripts

{% for script in site.scripts %}

### {{ script.title }}

{{ script.description }}

{% if script.requires_sudo %}
<p style="margin-top: 10px;">
  <em><strong style="color: #f0ad4e;">Note:</strong> This script requires <code>sudo</code> privileges to run.</em>
</p>
{% endif %}

{% if script.interactive %}

> **Installation:** This script is **interactive**. Please click "View Details" for install commands.

{% elsif script.no_pipe %}

**Quick Install (Download and run):**

```bash
curl -LO {{ script.script_url }} && {% if script.requires_sudo %}sudo {% endif %}bash {{ script.script_name }}
```

{% else %}

**Quick Install (One-Liner):**

```bash
curl -LO {{ script.script_url }} && chmod +x {{ script.script_name }} && {% if script.requires_sudo %}sudo {% endif %}./{{ script.script_name }}
```

{% endif %}

[📖 View Details & Source]({{ script.url }}) • [📥 Download]({{ script.script_url }}) • [🔗 Repository]({{ script.github_repo_url }})

---

{% endfor %}

## Need Help?

Check out the [main documentation](/) for detailed guides and setup instructions.
