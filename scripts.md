---
layout: default
title: Installation Scripts
nav_exclude: true
search_exclude: true
permalink: /scripts/
---

# Quick Installation Scripts

Professional, ready-to-use installation scripts for various tools and configurations.

{: .warning }
> **Security Best Practice**  
> Always review scripts before running them. Each script page shows its full source code for transparency.

## Available Scripts

{% for script in site.scripts %}
### {{ script.title }}

{{ script.description }}

{% if script.interactive %}
**Installation (Interactive Script):**

This script requires user input and cannot be piped directly to sh.

**Recommended Method:**

```bash
curl -fsSL {{ script.script_url }} -o {{ script.script_name }}
chmod +x {{ script.script_name }}
sudo ./{{ script.script_name }}
```

**One-Liner Alternative:**

```bash
bash -c "$(curl -fsSL {{ script.script_url }})"
```

{% else %}
**Quick Install:**

```bash
curl -fsSL {{ script.script_url }} | sh
```

{% endif %}

[📖 View Details & Source]({{ script.url }}) • [📥 Download]({{ script.script_url }}) • [🔗 Repository]({{ script.github_repo_url }})

---

{% endfor %}

## Need Help?

Check out the [main documentation](/) for detailed guides and setup instructions.
