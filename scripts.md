---
layout: default
title: Quick Install Scripts
nav_exclude: true
search_exclude: true
permalink: /scripts/
---

# Quick Install Scripts

{: .warning }
> **Always review scripts before running them with curl piping.**
> View the source code on GitHub first.

## Available Scripts

{% for script in site.scripts %}

### {{ script.title }}

{{ script.description }}

```bash
curl -fsSL https://buildplan.org/{{ script.slug }} | sh
```

[View Source]({{ script.github_raw_url }}) · [Repository]({{ script.github_repo_url }})

---
{% endfor %}
