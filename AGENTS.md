# AGENTS.md

This file provides guidance to Codex (Codex.ai/code) when working with code in this repository.

## What This Repo Is

A collection of Docker images for running [Bareos](https://www.bareos.org) (backup software) in containers. It does not contain application source code — it contains Dockerfiles, entrypoint shell scripts, and docker-compose files for deploying Bareos components.

## Components

Each component lives in its own directory with per-version subdirectories (e.g. `24-alpine`, `24-ubuntu`):

- **`director-pgsql/`** — Bareos Director (orchestrator) backed by PostgreSQL
- **`storage/`** — Bareos Storage Daemon
- **`client/`** — Bareos File Daemon (client)
- **`webui/`** — Bareos Web UI (PHP-FPM based)
- **`api/`** — Bareos REST API (Python/FastAPI, `bareos-restapi` pip package)
- **`bareos-db-migration/`** — MySQL → PostgreSQL migration tooling

Each version directory contains: `Dockerfile`, `docker-entrypoint.sh`, and sometimes `webhook-notify`.

## Building Images

```bash
# Build a specific component/version
docker build -t director-pgsql:24-ubuntu director-pgsql/24-ubuntu
docker build -t storage:24-ubuntu storage/24-ubuntu
docker build -t client:24-ubuntu client/24-ubuntu
docker build -t webui:24-ubuntu webui/24-ubuntu
docker build -t api:24-alpine api/24-alpine
```

## Running Locally

```bash
# Copy and configure env
cp .env.dist .env
# Edit .env with real passwords

# Start the stack (default symlink points to alpine-pgsql)
docker compose up -d

# Or specify a compose file explicitly
docker compose -f docker-compose-alpine-pgsql.yml up -d

# Enable DB init on first run (edit the compose file first)
# Set DB_INIT=true in the compose file before first launch
```

Available compose files: `docker-compose-alpine-pgsql.yml`, `docker-compose-ubuntu-pgsql.yml`. The `docker-compose.yml` symlink points to the alpine-pgsql variant.

## Accessing Services

```bash
# Bareos CLI console
docker exec -it bareos_bareos-dir_1 bconsole

# WebUI: http://localhost:8080 (admin / <BAREOS_WEBUI_PASSWORD>)
# REST API docs: http://localhost:8000/docs
# Prometheus metrics: http://localhost:9625/metrics
```

## How Entrypoint Scripts Work

The `docker-entrypoint.sh` in each component performs first-run configuration:

- Uses a sentinel file (`/etc/bareos/bareos-config.control`) to detect first run
- Unpacks bundled default config (`/bareos-dir.tgz`) and applies `sed` substitutions for env vars (DB credentials, host names, passwords)
- Director: supports `DB_INIT=true` to create PostgreSQL user/db and run Bareos schema scripts, and `DB_UPDATE=true` to run schema migrations
- Webhook notifications (Slack/Telegram) replace email notifications when `WEBHOOK_NOTIFICATION=true`

## Key Environment Variables

See `.env.dist` for all required variables. The most important ones for the Director:

| Variable | Purpose |
|---|---|
| `DB_INIT` | Set `true` on first run to create DB schema |
| `DB_UPDATE` | Set `true` to run DB migrations after upgrade |
| `DB_HOST`, `DB_PORT`, `DB_NAME`, `DB_USER`, `DB_PASSWORD` | Catalog DB connection |
| `DB_ADMIN_USER`, `DB_ADMIN_PASSWORD` | Used only for DB initialization |
| `BAREOS_SD_PASSWORD`, `BAREOS_FD_PASSWORD`, `BAREOS_WEBUI_PASSWORD` | Shared secrets between components |
| `SMTP_HOST`, `ADMIN_MAIL` | Mail reporting |
| `WEBHOOK_NOTIFICATION`, `WEBHOOK_TYPE`, `WEBHOOK_URL` | Slack/Telegram notifications |

## Git and GitHub Workflow

This repo is a fork. **Always push branches and open PRs against the fork (`origin`), never against the upstream repository.** When using `gh` commands, always pass `--repo` to target the fork explicitly.

## CI/CD

GitHub Actions workflows in `.github/workflows/`:

- `ci-director.yml`, `ci-client.yml`, `ci-storage.yml`, `ci-webui.yml`, `ci-api.yml` — build and push images; triggered on changes to the respective component directories
- `run-compose.yml` — integration test: spins up each compose variant and runs `bconsole` to verify the stack is healthy (runs weekly on Sundays and on compose file changes)
- `build-bareos-packages.yml` — builds `.deb` packages from the bareos source repo for versions not available on `download.bareos.org`; see `bareos-packages/README.md`
- `test-n-lint.yml` — linting
- `push-readme.yml` — syncs README to Docker Hub

The CI uses reusable composite actions in `.github/actions/` (prepare, build, push, test).

## Version Support

- Ubuntu images support `linux/amd64` only.
- Alpine architecture coverage is **per Bareos version**, not blanket amd64+arm64:

  | Bareos version | Alpine base | amd64 | arm64/v8 |
  |----------------|-------------|:-----:|:--------:|
  | 25             | 3.24        | ✓     | ✓        |
  | 24             | 3.23        | ✓     | ✓        |
  | 23             | 3.21        | ✓     | ✓        |

  amd64 installs straight from Alpine's official `community` repo. arm64/v8
  for 23/24/25 installs a package built by `bareos-alpine-packages/` — see its
  README before changing this table.
- Current active versions: 23–25 (Ubuntu and Alpine)
- MySQL backend was dropped upstream in Bareos 21+; this repo no longer
  carries `director-mysql/` images. This repo's own `bareos-db-migration/`
  ships Dockerfile source only — its image was never published (CI never
  builds it, confirmed 404 on Docker Hub) — so migrating an existing MySQL
  catalog to PostgreSQL means either building that image locally first or
  using upstream `barcus/bareos`'s working (but stale) `bareos-db-migration`
  compose file; see README's Database Migration section for both options.

### Removed platforms

`linux/arm/v7` support was dropped repo-wide on 2026-09-29 (it was previously
built only for Bareos 23's Alpine images, the sole version whose Alpine base
ships armv7 packages upstream — 24 and 25 were already hard-blocked by an
upstream `time_t`/`static_assert` mismatch in the filedaemon Python plugin on
32-bit ARM). It was removed for low usage and to drop QEMU/binfmt entirely
from this repo's CI (it was only ever used for the armv7 build job). The next
rebuild of the `23-alpine` tags will no longer include a `linux/arm/v7`
platform in the manifest; no action was
taken to freeze or preserve the existing manifest.

### Deprecated versions

Bareos 22 was dropped from active maintenance. Its `*/22-*` directories
remain in the tree for reference only and are excluded from CI. The existing
`darkvex/bareos-*:22-*` tags (Docker Hub and the private registry) remain
published as-is but will **not** receive further rebuilds, base-image bumps,
or CVE patches. Upgrade to v23, v24, or v25 for actively maintained images.
If you need an older version anyway, upstream `barcus/bareos` publishes
Bareos 18–22 (`22-alpine` only, no `22-ubuntu`; nothing for 16 or 17) — but
treat it as a fallback, not a recommendation: its `20`/`21` tags were last
pushed 2023-04-30 and its `22-alpine` 2025-01-12, none rebuilt since, and it
has no MySQL-backend variant.

Bareos 21 and older (`*/16-*` through `*/21-*`, plus the whole
`director-mysql/` component) have had their image source directories removed
from this repository — nothing under `darkvex/` publishes those tags
anymore, so there was no live tag left to document as deprecated the way v22
is. Use `git log -- <path>` (e.g. `git log -- director-pgsql/20-alpine`) to
retrieve the old Dockerfiles from history. For a live image at one of these
versions, see the `barcus/bareos` fallback noted above. The migration
tooling itself (`bareos-db-migration/`) was not removed — only the
per-version component directories were.

### Upstream package availability

`download.bareos.org` only publishes versioned repos for Bareos 20 and 21. For 22+:

| Bareos version | Ubuntu                          | Alpine (amd64)     |
|----------------|---------------------------------|---------------------|
| 20             | versioned apt repo              | Alpine 3.15         |
| 21             | versioned apt repo              | Alpine 3.17         |
| 22             | `current/` (serves 25.x today) | Alpine 3.18 (22.0.3)|
| 23             | not published upstream          | Alpine 3.21 (23.0.4)|
| 24             | not published upstream          | Alpine 3.23 (24.0.7)|
| 25             | `current/xUbuntu_24.04/`        | Alpine 3.24 (25.0.3)|

Use `bareos-packages/` to build `.deb` packages from source for Ubuntu versions
23–24. Alpine's own `community/bareos` package tracks upstream releases and
needs no source build for amd64 — only the arm64/v8 gap (every version) needs
`bareos-alpine-packages/`. Once packages are published as GitHub Releases, use
the `.agents/skills/add-bareos-version`
skill to generate new component directories that install from those artifacts —
its `references/upstream-sources.md` has the authoritative, verified table.
