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

Copy `.env.dist` to `.env` and change the passwords before production use:

```bash
cp .env.dist .env
```

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
