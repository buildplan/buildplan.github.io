---
layout: default
title: Installation Scripts
nav_exclude: true
search_exclude: true
permalink: /scripts/
---

# 🚀 Quick Installation Scripts

Professional, ready-to-use installation scripts for various tools and configurations.

{: .warning }
> **Security Best Practice**  
> Always review scripts before running them with `curl | sh`. Each script below shows its full source code for transparency.

## 📋 Available Scripts

{% for script in site.scripts %}
### {{ script.title }}

{{ script.description }}

**Quick Install:**

```bash
curl -fsSL {{ script.script_url }} | sh
```

[📖 View Details & Source]({{ script.url }}) • [📥 Download]({{ script.script_url }}) • [🔗 Repository]({{ script.github_repo_url }})

---
{% endfor %}

## 📚 Need Help?

Check out the [main documentation](/) for detailed guides and setup instructions.
