---
layout: default
title: Documentation Site with Jekyll and GitHub Pages
nav_order: 6
parent: Home
last_modified_date: 2025-07-11T22:20:27+01:00
---

### **A Guide to Creating a Documentation Site with Jekyll and GitHub Pages**

This guide will walk you through building a modern, dark-themed, and easy-to-maintain documentation website using Jekyll. We'll use the "Just the Docs" theme and host it for free on GitHub Pages. Finally, we'll connect it to a custom domain name.

### **Part 1: Building Your Jekyll Site**

#### **Step 1: Create the GitHub Repository**

First, you need a home for your website's code.

1.  **Create a New Repository:** On GitHub, create a new repository. For a user site, you must name it using the formula: `your-username.github.io`.

2.  **Clone the Repository:** Clone it to your local machine to get started.

    ```bash
    git clone https://github.com/your-username/your-username.github.io.git
    cd your-username.github.io
    ```

#### **Step 2: Configure Jekyll and Your Theme**

We'll use the "Just the Docs" theme by loading it directly from its repository, which is the most reliable method.

1.  **Create `_config.yml`:** This is your site's main configuration file. Create it in the root of your project.

    ```yaml
    # _config.yml

    # Use the theme directly from its GitHub repository
    remote_theme: just-the-docs/just-the-docs

    # --- Basic Site Settings ---
    title: "My Project Documentation"
    description: "A central hub for the documentation of all my projects."
    url: "https://your-username.github.io"

    # --- Theme Settings ---
    # Enable dark mode by default
    color_scheme: dark

    # --- Footer Settings ---
    # Show "Last edited on..." on pages with a 'last_modified_date'
    last_edit_timestamp: true
    last_edit_time_format: "%b %e, %Y" # e.g., "Jul 11, 2025"

    # Adds an "Edit this page on GitHub" link to the footer
    gh_edit_link: true
    gh_edit_link_text: "Edit this page on GitHub."
    gh_edit_repository: "https://github.com/your-username/your-username.github.io"
    gh_edit_branch: "main"
    ```

2.  **Create `Gemfile`:** This file tells GitHub which gems to use.

    ```ruby
    # Gemfile
    source "https://rubygems.org"
    gem "github-pages", group: :jekyll_plugins
    ```

#### **Step 3: Create Your Content**

1.  **Homepage (`index.md`):** Create an `index.md` file in the root of your project. This will be your site's landing page.

    ```markdown
    ---
    layout: default
    title: Home
    nav_order: 1
    ---

    # **Welcome to My Project Documentation!**

    This website hosts the documentation for my various GitHub repositories.

    ## **My Projects**

    * ### [Project One](./project-one/getting-started.html)
        A brief description of what Project One is all about.

    * ### [Project Two](./project-two/getting-started.html)
        A brief description of what Project Two is all about.
    ```

    *Note: We link to `.html` because that's what Jekyll builds, ensuring links work correctly.*

2.  **Project Pages:** Create a folder for each project you want to document. Inside that folder, create your Markdown files.

      * Create a folder named `project-one`.
      * Inside, create a file named `getting-started.md`.

    <!-- end list -->

    ```markdown
    ---
    layout: default
    title: Project One
    parent: Home
    last_modified_date: 2025-07-11T22:04:12+01:00
    ---

    # **Documentation for Project One**

    You can copy your `README.md` content here and expand on it with more detail, tutorials, and examples.
    ```

    **Important:** Notice the `last_modified_date`. You must add this to any page where you want the "Last edited on..." timestamp to appear.

#### **Step 4: Deploy Your Site**

Commit your files and push them to GitHub.

```bash
git add .
git commit -m "Build initial documentation site"
git push
```

GitHub Actions will automatically build and deploy your site. You can watch the progress in your repository's "Actions" tab. Your site will be live at `https://your-username.github.io` in a few minutes.

-----

### **Part 2: Adding a Custom Domain**

Once your site is live, you can point a custom domain name to it.

#### **Step 5: Configure the Domain in GitHub**

1.  Navigate to your repository on GitHub.
2.  Go to **Settings** \> **Pages**.
3.  Under the "Custom domain" section, enter your domain name (e.g., `www.your-domain.com`) and click **Save**. GitHub will automatically create a `CNAME` file in your repository.

#### **Step 6: Update Your DNS Records**

Log in to your domain registrar (like Namecheap, Google Domains, GoDaddy, etc.) and edit your DNS settings.

1.  **For the `www` Subdomain (CNAME Record):**
    This record points your subdomain to GitHub's servers.

      * **Type:** `CNAME`
      * **Host/Name:** `www`
      * **Value/Target:** `your-username.github.io` (replace `your-username` with your actual GitHub username)

2.  **For the Apex Domain (A & AAAA Records):**
    The apex domain (or root) is the version without `www` (e.g., `your-domain.com`). It must point directly to GitHub's IP addresses.

      * Create four **`A` records**:

          * **Type:** `A`
          * **Host/Name:** `@`
          * **Value/Points to:**
              * `185.199.108.153`
              * `185.199.109.153`
              * `185.199.110.153`
              * `185.199.111.153`
                *(You will create four separate A records, all with `@` as the host, pointing to each IP).*

      * Optionally, for IPv6 support, create four **`AAAA` records**:

          * **Type:** `AAAA`
          * **Host/Name:** `@`
          * **Value/Points to:**
              * `2606:50c0:8000::153`
              * `2606:50c0:8001::153`
              * `2606:50c0:8002::153`
              * `2606:50c0:8003::153`

    *Note: Some providers offer `ALIAS` or `ANAME` records, which can be used instead of `A` records to point your apex domain directly to `your-username.github.io`. Check your provider's documentation.*

#### **Step 7: Enforce HTTPS**

After a few hours, your DNS changes will propagate. Return to your GitHub Pages settings. You should see a message that your site is published at your custom domain.

**Make sure to check the "Enforce HTTPS" box.** This secures your site with a free SSL certificate from GitHub.
