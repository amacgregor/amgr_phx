# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Personal blog and portfolio site for [allanmacgregor.com](https://allanmacgregor.com), built with Elixir/Phoenix. Based on [bernheisel.com](https://github.com/dbernheisel/bernheisel.com). No database — content is compiled from markdown files at build time using NimblePublisher.

## Commands

```bash
# Setup
mix setup                    # Install deps + yarn assets

# Development
mix phx.server               # Start server at localhost:4040

# Quality checks
mix check                    # Runs format --check-formatted, sobelow, credo
mix format                   # Auto-format code
mix credo                    # Lint
mix sobelow -i Config.HTTPS  # Security scan
mix dialyzer                 # Type checking

# Tests
mix test                     # Run all tests
mix test path/to/test.exs    # Run single test file
mix test path/to/test.exs:42 # Run single test at line
mix coveralls.html           # Coverage report

# Assets
mix assets.deploy            # Build + digest for production
```

## Architecture

### Content System (NimblePublisher)

All content lives in `content/` as markdown files with YAML frontmatter, compiled into Elixir modules at build time:

- `content/posts/` → `Amgr.Blog` (blog posts)
- `content/til/` → `Amgr.Til` (Today I Learned)
- `content/eve/` → `Amgr.Eve` (Eve Online content)

Post filenames follow the pattern `YYYYMMDD-slug.md`. The date and slug are parsed from the filename in `Amgr.Blog.Post.build/3`. Posts have a `published: true` default — set `published: false` in frontmatter to hide from public listings while keeping accessible via `get_post_preview_by_id!/1`.

Each content context (`Blog`, `Til`, `Eve`) follows an identical pattern: NimblePublisher loads markdown, sorts by date descending, and exposes `all_posts/0`, `published_posts/0`, `get_post_by_id!/1`, and `get_posts_by_tag!/1`.

**Because content is compiled into the module, adding/editing a markdown file requires recompilation to take effect.**

### Web Layer

- **LiveView-based**: All pages use Phoenix LiveView (`lib/amgr_web/live/`)
- **Static pages** (about, projects, books) route through `Live.Page` with session-based page selection
- **SEO modules** in `lib/amgr_web/seo/` handle OpenGraph, breadcrumbs, and meta tags
- **RSS/Sitemap** served via `RobotController` and `SitemapController`
- **Presence tracking**: Real-time reader counts on blog posts via Phoenix PubSub

### Application Startup

`Amgr.Application` loads publications and services data into `:persistent_term` at startup (not from files — hardcoded in `application.ex`).

Supervision tree: Telemetry → PubSub → Presence → Endpoint.

### Key Dependencies

- `earmark` — custom fork (`dbernheisel/earmark`, branch `db-inline-code-smartypants`) for markdown with inline code smartypants support
- `plonk` — custom generator utilities (`amacgregor/plonk`)
- `nimble_publisher` — static site content from markdown

### Deployment

Deployed to **Fly.io** (`fly.toml`, app name `amgr-blog`). Multi-stage Docker build. CI runs via GitHub Actions (`.github/workflows/ci.yml`): format check → credo → sobelow → tests → deploy to Fly on main.

### Runtime Versions

Defined in `.tool-versions`: Elixir 1.13.3 (OTP 23), Erlang 23.3.2, Node.js 16.15.0.

### Environment Variables

- `AUTH_USER` / `AUTH_PASS` — basic auth for `/admin/dashboard` (defaults to admin/admin in dev)
