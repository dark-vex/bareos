# bareos

![License badge][license-img]
![Based OS][os-based-ubuntu] ![Based OS][os-based-alpine]
![Badge amd64][arch-amd64-img] ![Badge arm64][arch-arm64/v8-img] ![Badge armv7][arch-armv7-img]

Container images for running [Bareos][bareos-href] components with Docker and
Docker Compose.

## Images

| module | build | ubuntu size | alpine size | pull |
|:--|:--:|:--:|:--:|:--:|
| Director | [![Actions Status][build-director-img]][build-director-href] | ![Size badge][size-latest-director-png] | ![Size badge][size-alpine-director-png] | [![Docker badge][docker-img-dir]][docker-url-dir] |
| Storage Daemon | [![Actions Status][build-storage-img]][build-storage-href] | ![Size badge][size-latest-storage-png] | ![Size badge][size-alpine-storage-png] | [![Docker badge][docker-img-sd]][docker-url-sd] |
| Client/File Daemon | [![Actions Status][build-client-img]][build-client-href] | ![Size badge][size-latest-client-png] | ![Size badge][size-alpine-client-png] | [![Docker badge][docker-img-fd]][docker-url-fd] |
| Web UI | [![Actions Status][build-webui-img]][build-webui-href] | ![Size badge][size-latest-webui-png] | ![Size badge][size-alpine-webui-png] | [![Docker badge][docker-img-ui]][docker-url-ui] |
| API | [![Actions Status][build-api-img]][build-api-href] | | ![Size badge][size-latest-api-png] | [![Docker badge][docker-img-api]][docker-url-api] |

Weekly image builds run from GitHub Actions. Ubuntu images are built for
`linux/amd64` only. Alpine architecture coverage varies by Bareos version —
`linux/amd64` is always available, `linux/arm64/v8` is available for every
Alpine version, and `linux/arm/v7` is available for Bareos 23 only:

| Bareos version | Alpine base | amd64 | arm64/v8 | arm/v7 |
|:--|:--|:--:|:--:|:--:|
| 25 | Alpine 3.24 | ✅ | ✅ | ❌ |
| 24 | Alpine 3.23 | ✅ | ✅ | ❌ |
| 23 | Alpine 3.21 | ✅ | ✅ | ✅ |
| 22 | — | ✅ | — | — |

amd64 and, for Bareos 23, arm/v7 install Bareos straight from Alpine's
official `community` repository. arm64/v8 for Bareos 23/24/25 (and arm/v7 for
Bareos 24/25, which Alpine's own repository does not publish at all) install a
package built by this repo's `bareos-alpine-packages/` pipeline — Bareos 24
and 25 hit a real upstream bug on 32-bit ARM that rules out arm/v7 for those
two versions regardless of who builds the package; see
`bareos-alpine-packages/README.md` for details.

## Supported Tags

`bareos-director`:

| backend | tags |
|:--|:--|
| PostgreSQL | `25-ubuntu-pgsql`, `25-ubuntu`, `25`, `ubuntu` |
| PostgreSQL | `24-ubuntu-pgsql`, `24-ubuntu`, `24` |
| PostgreSQL | `23-ubuntu-pgsql`, `23-ubuntu`, `23` |
| PostgreSQL | `25-alpine-pgsql`, `25-alpine`, `alpine`, `latest` |
| PostgreSQL | `24-alpine-pgsql`, `24-alpine` |
| PostgreSQL | `23-alpine-pgsql`, `23-alpine` |

`bareos-client`, `bareos-storage`, and `bareos-webui`:

| base | tags |
|:--|:--|
| Ubuntu 24.04 | `25-ubuntu`, `25`, `ubuntu` |
| Ubuntu 24.04 | `24-ubuntu`, `24` |
| Ubuntu 22.04 | `23-ubuntu`, `23` |
| Alpine 3.24 | `25-alpine`, `alpine`, `latest` |
| Alpine 3.23 | `24-alpine` |
| Alpine 3.21 | `23-alpine` |

`bareos-api`:

| tags |
|:--|
| `25-alpine` |
| `24-alpine`, `24`, `alpine`, `latest` |
| `23-alpine` |

The currently published `api/23-alpine` through `api/25-alpine` images are
built from `python:3.14-alpine` and install the `bareos-restapi` PyPI package
pinned to that Bareos version; only the latest version (currently 24) also
gets the bare `24`, `alpine`, and `latest` tags.

The `api/22-alpine` directory is present in the source tree but not built or
published: that `bareos-restapi` release pulls in a `pydantic` version its
model code can't parse (fails on import with `PydanticSchemaGenerationError`),
while 23+ import cleanly.

## Deprecated Tags

Bareos 22 has been dropped from active maintenance. The tags below remain
published and pullable exactly as they are today, but will **not** be
rebuilt, re-tagged, or patched for new CVEs. Use Bareos 23, 24, or 25 for
actively maintained images.

| image | tags |
|:--|:--|
| `bareos-director` | `22-ubuntu-pgsql`, `22-ubuntu`, `22`, `22-alpine-pgsql`, `22-alpine` |
| `bareos-client` | `22-ubuntu`, `22`, `22-alpine` |
| `bareos-storage` | `22-ubuntu`, `22`, `22-alpine` |
| `bareos-webui` | `22-ubuntu`, `22`, `22-alpine` |
| `bareos-api` | none — Bareos 22 was never built or published for `bareos-api` |

## Version Support

| Bareos version | Ubuntu image | Alpine image | API image | Notes |
|:--|:--|:--|:--|:--|
| 25 | `25-ubuntu` on Ubuntu 24.04 | `25-alpine` on Alpine 3.24 | `25-alpine` | Ubuntu from `download.bareos.org/current/`; Alpine amd64+arm64/v8 |
| 24 | `24-ubuntu` on Ubuntu 24.04 | `24-alpine` on Alpine 3.23 | `24-alpine` (latest) | Ubuntu from GitHub package release; Alpine amd64+arm64/v8 |
| 23 | `23-ubuntu` on Ubuntu 22.04 | `23-alpine` on Alpine 3.21 | `23-alpine` | Ubuntu from GitHub package release; Alpine amd64+arm64/v8+arm/v7 |
| 22 | `22-ubuntu` on Ubuntu 22.04 | `22-alpine` on Alpine 3.18 | — | Deprecated: existing tags remain published but frozen, no further rebuilds or CVE patches (see Deprecated Tags above); `bareos-restapi` 22.x fails to import (see `bareos-api` tags above) |
| 21 and older | — | — | — | Removed from this repository — git history keeps the old Dockerfiles. No `16`–`21` tag remains on Docker Hub under `darkvex/`; `director-mysql/` (MySQL catalog backend, dropped upstream in Bareos 21) was removed in full. See the notes below for an upstream fallback and the MySQL migration path. |

Upstream `barcus/bareos` (the project this repo was forked from) still
publishes Bareos 18–22 images (`barcus/bareos-director:21-ubuntu`, etc.) —
a fallback if you need one of these versions, not a recommendation: its
`20`/`21` tags were last pushed 2023-04-30 and its `22-alpine` 2025-01-12,
none of them have been rebuilt since, there's no `22-ubuntu` there, and
nothing for Bareos 16 or 17 exists anywhere, upstream included. Bareos
removed the MySQL catalog backend upstream in version 21 — see Database
Migration below for moving an existing MySQL catalog to PostgreSQL.

Bareos 23 removed the `dbdriver` directive from the catalog resource. If you
are upgrading from Bareos 22 or older, remove any `dbdriver = "postgresql"`
line from `/etc/bareos/bareos-dir.d/catalog/MyCatalog.conf` before starting
the Director. Leaving it in place causes a fatal config error:

```
bareos-dir: CONFIG ERROR at lib/parse_conf_state_machine.cc:161
Config error: Keyword "dbdriver" not permitted in this resource.
```

**Existing deployments:** `docker-compose-alpine-pgsql.yml` (the default `docker-compose.yml`
target) now pins Bareos 25 rather than 21. If you have an existing, volume-backed deployment
from that file still running Bareos 21, pulling the new images and restarting will **not**
auto-migrate your catalog config — the entrypoint's first-run sentinel file
(`/etc/bareos/bareos-config.control`) only unpacks the bundled default config on a genuinely
first run, so an existing `/data/bareos/config/director` volume keeps its Bareos 21 config as-is.
You must manually apply any config changes required for the Bareos 21 → 25 jump yourself
(including the `dbdriver` removal above, if not already done) before restarting the Director
against the new image.

## Package Releases

`download.bareos.org/current/` tracks the latest Bareos release and does not
provide pinned 23 or 24 Ubuntu repositories. This repo builds pinned `.deb`
packages from upstream Bareos release tags and publishes them as GitHub Release
assets.

The Ubuntu 23/24 Dockerfiles consume the package release
`pkg/bareos-packages-v1`:

| asset | used by |
|:--|:--|
| `bareos-23-jammy.tar.gz` | `23-ubuntu` component images |
| `bareos-24-noble.tar.gz` | `24-ubuntu` component images |

See [bareos-packages/README.md][bareos-packages-readme] for local package
builds and release publishing details.

## Setup

Bareos Director requires:

* PostgreSQL for supported current stacks
* SMTP relay or webhook notifications for reports

Bareos Web UI requires either its Ubuntu Apache image or, for Alpine stacks,
the paired PHP-FPM service used by the compose file.

Bareos Client/File Daemon and Storage Daemon have no external service
dependency beyond the Director connection.

## Requirements

* [Docker][docker-href]
* [Docker Compose][docker-compose-href]

## Usage

Copy `.env.dist` to `.env` and set every `*_PASSWORD` before starting the
stack — they ship empty and containers refuse to start until you do; see
[Secrets](#secrets) below.

```bash
cp .env.dist .env
```

The bundled `postgres` service requires
`POSTGRES_INITDB_ARGS=--encoding=SQL_ASCII` (already set in the compose
files) because the Bareos catalog schema needs that encoding — keep it if you
customize the database service.

Start the default stack:

```bash
docker compose up -d
```

Or choose a compose file explicitly:

```bash
docker compose -f docker-compose-alpine-pgsql.yml up -d
docker compose -f docker-compose-ubuntu-pgsql.yml up -d
```

Available compose files:

| file | backend | status |
|:--|:--|:--|
| [docker-compose-alpine-pgsql.yml][compose-alpine-pgsql-href] | PostgreSQL | Alpine example stack |
| [docker-compose-ubuntu-pgsql.yml][compose-ubuntu-pgsql-href] | PostgreSQL | Ubuntu example stack |

The compose examples store data under `/data/(bareos|pgsql)`.

The Alpine compose files also run a `php-fpm` sidecar for the WebUI. In
`docker-compose-alpine-pgsql.yml` it uses the `darkvex/bareos-webui` image
itself, which ships PHP-FPM listening on port 9000, started with
`entrypoint: ["/usr/local/sbin/php-fpm"]`. The third-party images
(PostgreSQL, the SMTP relay and the metrics exporter) are pinned by digest.

The WebUI, REST API and metrics ports are published on `127.0.0.1` only, so
the examples don't expose them to the network by default. Put a reverse
proxy with TLS in front of them, or change the port mapping (for example
`8080:9100` instead of `127.0.0.1:8080:9100`) if you really need direct
remote access. The storage daemon port `9103` stays published on all
interfaces because file daemons on other hosts connect to it.

## Secrets

Every `*_PASSWORD` variable in `.env.dist` ships empty. On startup, each
entrypoint refuses to run if a password it needs is empty, or still equals a
retired example value that used to ship in `.env.dist` (e.g.
`ThisIsMySecretDBp4ssw0rd`) — this catches `.env` files copied from an old
version of this repo, not just unset variables.

Every `*_PASSWORD` also has a `*_FILE` variant for the
[Docker/Kubernetes secrets convention][docker-secrets-href] (the same one
used by the official `postgres`/`mysql` images): point it at a file
containing the password instead of setting the variable directly. Setting
both the plain variable and its `_FILE` variant for the same password is
rejected. The file's contents are read as-is (trailing newlines stripped); a
file containing only a newline is treated as empty and rejected.

Supported `*_FILE` variables:

| Component | Plain variable | `_FILE` variable |
|:--|:--|:--|
| director-pgsql | `DB_PASSWORD` | `DB_PASSWORD_FILE` |
| director-pgsql | `DB_ADMIN_PASSWORD`* | `DB_ADMIN_PASSWORD_FILE` |
| director-pgsql, storage | `BAREOS_SD_PASSWORD` | `BAREOS_SD_PASSWORD_FILE` |
| director-pgsql, client | `BAREOS_FD_PASSWORD` | `BAREOS_FD_PASSWORD_FILE` |
| director-pgsql | `BAREOS_WEBUI_PASSWORD` | `BAREOS_WEBUI_PASSWORD_FILE` |
| api | `JWT_SECRET` | `JWT_SECRET_FILE` |
| bareos-db-migration | `MYSQL_DB_PASSWORD` | `MYSQL_DB_PASSWORD_FILE` |
| bareos-db-migration | `PGSQL_DB_PASSWORD` | `PGSQL_DB_PASSWORD_FILE` |
| bareos-db-migration | `PGSQL_ADMIN_PASSWORD` | `PGSQL_ADMIN_PASSWORD_FILE` |

\* `DB_ADMIN_PASSWORD` is only required when `DB_INIT=true` or
`DB_UPDATE=true` (it's only used to connect as the PostgreSQL admin user for
schema init/migration) — otherwise it can be left unset.

`MYSQL_ADMIN_PASSWORD` has no `_FILE` variant: the `bareos-db-migration`
entrypoint never reads it directly, it's only forwarded by
`bareos-db-migration/docker-compose.yml` to the official `mysql` image as
`MYSQL_ROOT_PASSWORD`, which already supports `MYSQL_ROOT_PASSWORD_FILE`
natively — pass that instead if you need file-based secrets there.

The bundled compose files (`docker-compose-*.yml`) still pass passwords as
plain `environment:` variables, not Docker Compose `secrets:` — if you want
`secrets:`-based wiring, adapt the compose files yourself; the entrypoints
support either since `_FILE` just needs a readable file path.

**Rotation caveat:** entrypoints only write daemon configs on first run,
gated by a sentinel file (`/etc/bareos/bareos-config.control` or
equivalent). Changing a password in `.env` and restarting an
already-initialized container does **not** rotate the password baked into
that daemon's config — remove the sentinel file (or edit the config
directly) to pick up a new value.

## Access

Web UI:

```text
http://localhost:8080
```

Default user is `admin`; the password is `BAREOS_WEBUI_PASSWORD`.

Bareos console:

```bash
docker exec -it bareos-dir bconsole
```

On Bareos 24+ images, `BAREOS_WEBUI_PASSWORD` is also reused as the
Director's own local console password (what `bconsole` above authenticates
with) and its tray-monitor console — those bundled resources ship with an
empty password that Bareos now rejects at startup, and there's no separate
`.env` variable for them. Unlike the WebUI's console, which is
ACL-restricted (denies `.sql`, `configure`, `create`, `delete`, `purge`,
etc.), the Director's local console has no ACL — treat this password as a
full-privilege credential, not just a WebUI login.

REST API docs:

```text
http://localhost:8000/docs
```

Prometheus metrics:

```text
http://localhost:9625/metrics
```

Metrics are provided by [bareos_exporter][bareos-exporter-href] and should be
scraped by [Prometheus][prometheus-href].

## Verifying Images

Images published from `master` are signed with [cosign][cosign-href] keyless
signing through GitHub Actions OIDC, and carry an SPDX SBOM and a SLSA
provenance attestation. Signatures are made on image digests, so resolve the
tag first and verify the digest:

```bash
image=darkvex/bareos-director:25-alpine-pgsql
digest=$(docker buildx imagetools inspect "$image" --format '{{json .Manifest}}' | jq -r .digest)

cosign verify "darkvex/bareos-director@${digest}" \
  --certificate-identity-regexp '^https://github.com/dark-vex/bareos/\.github/workflows/ci-[a-z]+\.yml@refs/heads/master$' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com

cosign verify-attestation --type spdxjson "darkvex/bareos-director@${digest}" \
  --certificate-identity-regexp '^https://github.com/dark-vex/bareos/\.github/workflows/ci-[a-z]+\.yml@refs/heads/master$' \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

Use `--type slsaprovenance` to verify the provenance attestation instead of
the SBOM.

## Container Hardening

The example compose files (`docker-compose-alpine-pgsql.yml`,
`docker-compose-ubuntu-pgsql.yml`) apply `security_opt: [no-new-privileges:true]`,
a minimal `cap_drop: [ALL]` + `cap_add:` per service, and `read_only: true` +
`tmpfs:` where that's safe, to every Bareos-authored service (`bareos-dir`,
`bareos-sd`, `bareos-fd`, `bareos-webui`, the alpine `php-fpm` sidecar, and
`bareos-api`). `bareos-db` (postgres) and `smtpd` (exim) are intentionally
**not** hardened here — they're third-party images outside this ticket's
scope; hardening them is a natural follow-up.

### Why each capability is there

Director, Storage and Client/FD all start as root and drop privileges
themselves (Bareos' own `-u bareos` flag for dir/sd, `su-exec`/`setpriv` in
the FD entrypoint) — this needs `CAP_SETUID`/`CAP_SETGID` (the drop itself)
and three capabilities around the entrypoint's first-run config extraction:

* `CAP_CHOWN` — the entrypoint's own chown fixups, and GNU tar's
  `--same-owner` (its default as root) chowning each extracted config entry
  to `bareos`.
* `CAP_DAC_OVERRIDE` — `/etc/bareos` itself is baked `bareos:root` (or
  `bareos:bareos` on ubuntu) in the image; root matches neither its owner
  nor (on alpine) its group, so without this, root can't even write new
  top-level entries into it.
* `CAP_FOWNER` — after tar chowns an entry to `bareos`, it chmods that same
  entry back to its recorded mode (GNU tar's `--preserve-permissions`
  default as root) — but `chmod()` requires `CAP_FOWNER` whenever the
  caller's uid no longer matches the file's owner, regardless of which bits
  are being set.

Missing either `DAC_OVERRIDE` or `FOWNER` doesn't degrade gracefully: GNU
tar reports `Cannot change mode to ...: Operation not permitted` (or
`Cannot rename to ...`), aborts the whole extraction, and the daemon crashes
before it can start — on the very first run of a fresh volume, every time.
**This was not caught by extensive local testing** (fresh-init runs,
restarts, full backup+restore cycles, repeated many times) because that
testing bind-mounted paths under Docker Desktop for Mac's macOS
file-sharing layer (virtiofs/osxfs), which does not faithfully replicate
these kernel-level permission checks. It only surfaced once this branch's
actual CI run exercised a genuine Linux bind mount on GitHub's native
runner — confirmed by reproducing the exact failure locally afterward using
real Docker volumes instead of macOS bind mounts, and by verifying the fix
the same way before pushing it. Take this as a concrete reminder that
"tested locally on macOS" and "tested against a real Linux host" are not
the same claim for anything touching filesystem permissions under Docker.

`bareos-api` never runs as root at all (`USER 1000` from `ENTRYPOINT`), so
it needs no added capabilities beyond dropping everything.

webui was verified empirically before writing any code: both flavors already
self-drop privileges the same way the Bareos daemons and Apache do, so **no
Dockerfile or entrypoint changes were needed**:

* alpine: nginx ships `user nginx;` in `nginx.conf`, and php-fpm's `www.conf`
  ships `user = nobody` / `group = nobody` — both untouched by this repo's
  own `zz-docker.conf` overlay.
* ubuntu: Apache uses the standard Debian `APACHE_RUN_USER=www-data` /
  `APACHE_RUN_GROUP=www-data` envvars, and php-fpm's `www.conf` ships
  `user = www-data` / `group = www-data`.

Both still need `CAP_SETUID`/`CAP_SETGID` for that master-to-worker drop, and
`CAP_CHOWN` for the socket/tmp-dir handoff. Two capabilities were only found
necessary by actually running the hardened containers, not by reading source:

* `CAP_DAC_OVERRIDE` on **both** webui flavors — Alpine's `bareos-webui-nginx`
  package ships `/var/lib/nginx` as `nginx:nginx 0750`, and Debian's php-fpm
  package ships `/run/php` as `www-data:www-data 0755`. Without this
  capability, root is evaluated as "other" against those modes and can't even
  traverse into them — `cap_drop: ALL` removes root's usual free pass around
  file permission checks, it isn't only about setuid/setgid.
* `CAP_NET_BIND_SERVICE` on ubuntu webui only — Apache listens on port 80.
  (The alpine flavor listens on 9100, so it doesn't need this.)

### `read_only` exceptions

Two services deliberately do **not** get `read_only: true`, because a tmpfs
mount hides whatever the image baked in at that same path rather than
overlaying it:

* **webui** (both flavors): the entrypoint unconditionally rewrites
  `/etc/nginx/http.d/bareos-webui.conf` (alpine) or
  `/etc/apache2/sites-available/000-default.conf` (ubuntu) on *every* start —
  neither path is a bind mount. Making `/etc/nginx` or `/etc/apache2`
  read-only blocks that rewrite outright; tmpfs-mounting them instead erases
  the whole image-baked config directory before the entrypoint even runs.
* **api**: `pip install` lands the `uvicorn` entrypoint and all site-packages
  under `/home/bareos` at build time, and the entrypoint rewrites
  `/home/bareos/api.ini` on every start. A tmpfs at `/home/bareos` (needed to
  allow that write under `USER 1000`, which has no root phase to `chown` a
  fresh mount) shadows the pip install too, breaking the container with
  `uvicorn: not found`. Confirmed by actually running it, not inferred.

### The tmpfs-inherits-baked-mode gotcha

Testing surfaced an undocumented Docker behavior: a bare `tmpfs:` entry
doesn't reliably default to the usual `/tmp`-style `1777`. When the target
path already exists in the image (as most of these do — the Dockerfiles
`mkdir`/package-install them with specific ownership), the tmpfs mount that
replaces it seems to inherit that existing *mode* while resetting the
*owner* to root. A path the image ships as `bareos:bareos 0755` becomes
`root:root 0755` once tmpfs-mounted — root can still write it (owner match),
but the unprivileged daemon user cannot, silently, with no container-level
failure. Reproduced directly against `alpine:3.24`/`ubuntu:noble` (which
lack these paths and correctly default to `1777`) versus the real
`darkvex/bareos-*` images (which have them pre-baked and come up `0755`).

This bit two services whose entrypoints don't `chown` a path this hardening
now tmpfs-mounts:

* **ubuntu director**'s entrypoint
  (`director-pgsql/25-ubuntu/docker-entrypoint.sh`) only `chown`s
  `/var/lib/bareos`, not `/var/log/bareos` — unlike its alpine counterpart,
  which chowns both. Broke the daemon's own file logging (`fopen ...
  bareos.log failed: Permission denied`) without failing the container or
  the healthcheck.
* **`bareos-sd`**, on both flavors, never `chown`s `/var/log/bareos` at all.
  Invisible in this repo's default compose (storage's default Messages
  resource has no `File =` destination, so nothing writes there), but a
  latent trap for any operator who adds file-based sd logging later.

Both are worked around in the compose files with `tmpfs:
/var/log/bareos:mode=1777`, not an entrypoint edit — **this is a deliberate
scope decision, not the only fix.** The cleaner long-term fix is a one-line
`chown` added to the affected entrypoints (matching what alpine director and
the FD entrypoints already do), but that needs a CI image rebuild before it
would help anyone running the *published* `darkvex/bareos-*` tags, so
`mode=1777` is what actually works against images available today. Revisit
once those entrypoints are patched and rebuilt.

`bareos-sd` also has a plain (no `mode=`) `/var/lib/bareos` tmpfs entry, and
it's worth spelling out *why* since it's easy to mistake for the same
gotcha: `/var/lib/bareos` on both flavors is already baked `bareos`-owned,
so the entrypoint's own conditional `find ... -exec chown` never touches it
— an earlier draft of this entry claimed "entrypoint chowns it directly,"
which a from-source review correctly flagged as unverified, and removing
the entry passed a backup-only test cleanly. Only running an actual
*restore* surfaced the real reason it's needed: `bareos-sd` itself writes a
bootstrap file straight to `/var/lib/bareos/bareos-sd.<job>.bootstrap` (a
sibling of the `archive`/`storage` bind mount, not inside it) on every
restore, and that fails outright under `read_only: true` without this
entry. A backup-only smoke test cannot catch this — it's restore-specific.

### Operational caveats

* **FD and arbitrary host paths**: the bundled `SelfTest` fileset (what
  `backup-bareos-fd` actually backs up by default) reads fine under
  `cap_drop: ALL` — confirmed by running it. If you point `bareos-fd` at
  arbitrary host paths instead, the restricted capability set here may not be
  enough to read them — `FORCE_ROOT=true` (which skips the privilege drop
  entirely) or adding `CAP_DAC_READ_SEARCH` are both options; that trade-off
  is operator-specific and intentionally not a default.
* **`PUID`/`PGID` vs. `read_only`**: the commented-out `PUID`/`PGID` options
  in `bareos-fd` call `usermod -u`/`groupmod -g`, which write to
  `/etc/passwd`/`/etc/group`. Those paths are read-only under this hardening,
  so uncommenting `PUID`/`PGID` on an already-hardened `bareos-fd` will fail;
  drop `read_only: true` for that service if you need them.
* **Restores need `/tmp` writable on `bareos-fd`**: the bundled `RestoreFiles`
  job's default `Where = "/tmp/bareos-restores"` failed outright
  (`Cannot create directory /tmp/bareos-restores: ERR=Read-only file
  system`) until `/tmp` was added to `bareos-fd`'s `tmpfs:` list — found only
  by actually running a restore, not by reading source. If you redirect
  restores elsewhere (a bind-mounted path), that path needs the same
  attention.

### Version coverage

`bconsole` connecting only proves the director's TCP listener and console
auth work — it exercises none of the actual write paths this hardening
touches (see the `DAC_OVERRIDE`/`FOWNER` writeup above for how much that
mattered in practice). The trustworthy verification here comes from two
sources: `run-compose.yml` itself running on GitHub's native `ubuntu-latest`
runner — a genuine Linux bind mount, not a macOS one — and, for the deeper
functional check, a real `backup-bareos-fd` job followed by a full restore
of everything it wrote (fd reads its fileset under `cap_drop: ALL`, sd
writes a volume into the archive/storage directory — a bind mount nested
under a tmpfs-mounted parent, under `read_only: true` — and dir inserts the
resulting file attributes into the catalog), run locally but against
genuine Docker **volumes** rather than macOS bind mounts, with container
logs swept for `Permission denied`/`EPERM`/`Cannot change mode`/read-only-fs
errors on every run:

| Version | CI: fresh init + `bconsole` (real Linux bind mount) | Backup + restore job (genuine Docker volume) |
|:--|:-:|:-:|
| 25-alpine | ✓ | ✓ |
| 25-ubuntu | ✓ | ✓ |
| 24-alpine | – | – |
| 23-alpine | – | – |
| 23-ubuntu | – | – |
| 24-ubuntu | – | – |

24-alpine and 23-alpine were run successfully earlier in this branch's
history, but *before* the `DAC_OVERRIDE`/`FOWNER` fix landed, and only
through the macOS bind-mount path that turned out not to catch the bug that
fix addresses — so that earlier result is stale evidence, not a current
pass, and both are listed unverified here until rerun against the final
compose files. (The `BackupCatalog` job, the other job the default config
ships, fails on *both* hardened and unhardened stacks with `Script
signature has changed: usage /etc/bareos/scripts/make_catalog_backup
CatalogName` — a pre-existing config/script mismatch unrelated to this
ticket, confirmed by isolating against the unhardened baseline. Worth its
own issue.)

23-ubuntu and 24-ubuntu could **not** be verified locally at all —
`bareos-webui:23-ubuntu`'s php-fpm segfaults under this machine's QEMU
x86_64 emulation (Apple Silicon host). The same crash reproduces identically
against the *unhardened* baseline image, so it's a local emulation
limitation, not a hardening regression, but it's still an unverified gap
against real amd64 hardware — don't treat 23/24-ubuntu as confirmed working
until someone runs this on native amd64. `run-compose.yml` only ever
exercises the v25 tags baked into the default compose files, so 23/24 in
general depend on manual verification like this rather than CI.
`docker-compose-ubuntu-pgsql.override.yml` (mirroring the existing
`docker-compose-alpine-pgsql.override.yml`) was added for that purpose —
usage:

```bash
BAREOS_UBUNTU_TAG=23-ubuntu docker compose \
  -f docker-compose-ubuntu-pgsql.yml -f docker-compose-ubuntu-pgsql.override.yml up -d
```

## Database Migration

Bareos 21 and newer do not ship the MySQL catalog backend. To migrate an
existing MySQL catalog, upgrade to Bareos 20 first, then copy the catalog
into PostgreSQL. This repo's own [`bareos-db-migration/`][compose-db-migration-href]
directory has Dockerfile source but no published image — CI has never built
or pushed `darkvex/bareos-db-migration` — so its `docker-compose.yml` won't
pull as shipped unless you build the image yourself first
(`docker build -t darkvex/bareos-db-migration bareos-db-migration/`).
Upstream `barcus/bareos` publishes a working, if stale (last updated
2022-03-01), `barcus/bareos-db-migration:latest` image with its own compose
file — see
[barcus/bareos's `bareos-db-migration/docker-compose.yml`](https://github.com/barcus/bareos/blob/master/bareos-db-migration/docker-compose.yml)
if you want something that pulls out of the box.

If the target PostgreSQL database is empty or does not exist, the migration
tool creates it. Keep `.env` available with the required database passwords.

The same empty-by-default, refuse-on-placeholder behavior described in
[Secrets](#secrets) applies to the migration tool's password variables
(`MYSQL_DB_PASSWORD`, `PGSQL_DB_PASSWORD`, `PGSQL_ADMIN_PASSWORD`, each with
a matching `_FILE` variant).

## Building Images

Build a specific component/version:

```bash
docker build -t bareos-director:24-ubuntu director-pgsql/24-ubuntu
docker build -t bareos-storage:24-ubuntu storage/24-ubuntu
docker build -t bareos-client:24-ubuntu client/24-ubuntu
docker build -t bareos-webui:24-ubuntu webui/24-ubuntu
docker build -t bareos-api:24-alpine api/24-alpine
```

For Ubuntu 23/24 images, the package release assets must exist before the
build can download them.

## Links

* [Bareos documentation][bareos-doc]
* [director-pgsql][repo-director-pgsql]
* [storage][repo-storage]
* [client][repo-client]
* [webui][repo-webui]
* [api][repo-api]

[arch-amd64-img]: https://img.shields.io/badge/arch-amd64-inactive
[arch-arm64/v8-img]: https://img.shields.io/badge/arch-arm64/v8-inactive
[arch-armv7-img]: https://img.shields.io/badge/arch-arm/v7-inactive
[bareos-href]: https://www.bareos.org
[bareos-doc]: https://www.bareos.com/learn/documentation
[bareos-packages-readme]: https://github.com/Dark-Vex/bareos/blob/master/bareos-packages/README.md
[build-client-href]: https://github.com/Dark-Vex/bareos/actions/workflows/ci-client.yml
[build-client-img]: https://github.com/Dark-Vex/bareos/actions/workflows/ci-client.yml/badge.svg
[build-director-href]: https://github.com/Dark-Vex/bareos/actions/workflows/ci-director.yml
[build-director-img]: https://github.com/Dark-Vex/bareos/actions/workflows/ci-director.yml/badge.svg
[build-storage-href]: https://github.com/Dark-Vex/bareos/actions/workflows/ci-storage.yml
[build-storage-img]: https://github.com/Dark-Vex/bareos/actions/workflows/ci-storage.yml/badge.svg
[build-webui-href]: https://github.com/Dark-Vex/bareos/actions/workflows/ci-webui.yml
[build-webui-img]: https://github.com/Dark-Vex/bareos/actions/workflows/ci-webui.yml/badge.svg
[build-api-href]: https://github.com/Dark-Vex/bareos/actions/workflows/ci-api.yml
[build-api-img]: https://github.com/Dark-Vex/bareos/actions/workflows/ci-api.yml/badge.svg
[compose-alpine-pgsql-href]: https://github.com/Dark-Vex/bareos/blob/master/docker-compose-alpine-pgsql.yml
[compose-ubuntu-pgsql-href]: https://github.com/Dark-Vex/bareos/blob/master/docker-compose-ubuntu-pgsql.yml
[compose-db-migration-href]: https://github.com/Dark-Vex/bareos/blob/master/bareos-db-migration/docker-compose.yml
[docker-compose-href]: https://docs.docker.com/compose
[cosign-href]: https://github.com/sigstore/cosign
[docker-href]: https://docs.docker.com/engine/install/
[docker-secrets-href]: https://docs.docker.com/engine/swarm/secrets/
[docker-img-dir]: https://img.shields.io/docker/pulls/darkvex/bareos-director?label=bareos-director&logo=docker
[docker-img-fd]: https://img.shields.io/docker/pulls/darkvex/bareos-client?label=bareos-client&logo=docker
[docker-img-sd]: https://img.shields.io/docker/pulls/darkvex/bareos-storage?label=bareos-storage&logo=docker
[docker-img-ui]: https://img.shields.io/docker/pulls/darkvex/bareos-webui?label=bareos-webui&logo=docker
[docker-img-api]: https://img.shields.io/docker/pulls/darkvex/bareos-api?label=bareos-api&logo=docker
[docker-url-dir]: https://registry.hub.docker.com/r/darkvex/bareos-director
[docker-url-fd]: https://registry.hub.docker.com/r/darkvex/bareos-client
[docker-url-sd]: https://registry.hub.docker.com/r/darkvex/bareos-storage
[docker-url-ui]: https://registry.hub.docker.com/r/darkvex/bareos-webui
[docker-url-api]: https://registry.hub.docker.com/r/darkvex/bareos-api
[license-img]: https://img.shields.io/badge/License-MIT-yellow.svg
[os-based-alpine]: https://img.shields.io/badge/os-alpine-9cf
[os-based-ubuntu]: https://img.shields.io/badge/os-ubuntu-9cf
[prometheus-href]: https://prometheus.io
[bareos-exporter-href]: https://github.com/vierbergenlars/bareos_exporter
[repo-api]: https://github.com/Dark-Vex/bareos/tree/master/api
[repo-client]: https://github.com/Dark-Vex/bareos/tree/master/client
[repo-director-pgsql]: https://github.com/Dark-Vex/bareos/tree/master/director-pgsql
[repo-storage]: https://github.com/Dark-Vex/bareos/tree/master/storage
[repo-webui]: https://github.com/Dark-Vex/bareos/tree/master/webui
[size-alpine-client-png]: https://img.shields.io/docker/image-size/darkvex/bareos-client/alpine?label=alpine&style=plastic
[size-alpine-director-png]: https://img.shields.io/docker/image-size/darkvex/bareos-director/alpine?label=alpine&style=plastic
[size-alpine-storage-png]: https://img.shields.io/docker/image-size/darkvex/bareos-storage/alpine?label=alpine&style=plastic
[size-alpine-webui-png]: https://img.shields.io/docker/image-size/darkvex/bareos-webui/alpine?label=alpine&style=plastic
[size-latest-client-png]: https://img.shields.io/docker/image-size/darkvex/bareos-client/latest?label=latest&style=plastic
[size-latest-director-png]: https://img.shields.io/docker/image-size/darkvex/bareos-director/latest?label=latest&style=plastic
[size-latest-storage-png]: https://img.shields.io/docker/image-size/darkvex/bareos-storage/latest?label=latest&style=plastic
[size-latest-webui-png]: https://img.shields.io/docker/image-size/darkvex/bareos-webui/latest?label=latest&style=plastic
[size-latest-api-png]: https://img.shields.io/docker/image-size/darkvex/bareos-api/latest?label=latest&style=plastic
