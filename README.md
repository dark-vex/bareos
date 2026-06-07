# bareos

![License badge][license-img]
![Based OS][os-based-ubuntu] ![Based OS][os-based-alpine]
![Badge amd64][arch-amd64-img] ![Badge arm64][arch-arm64/v8-img]

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

Weekly image builds run from GitHub Actions. Alpine images are built for
`linux/amd64` and `linux/arm64/v8`; Ubuntu images are currently built for
`linux/amd64`.

## Supported Tags

`bareos-director`:

| backend | tags |
|:--|:--|
| PostgreSQL | `25-ubuntu-pgsql`, `25-ubuntu`, `25`, `ubuntu` |
| PostgreSQL | `24-ubuntu-pgsql`, `24-ubuntu`, `24` |
| PostgreSQL | `23-ubuntu-pgsql`, `23-ubuntu`, `23` |
| PostgreSQL | `22-ubuntu-pgsql`, `22-ubuntu`, `22` |
| PostgreSQL | `22-alpine-pgsql`, `22-alpine`, `alpine`, `latest` |
| PostgreSQL | `21-ubuntu-pgsql`, `21-ubuntu`, `21` |
| PostgreSQL | `21-alpine-pgsql`, `21-alpine` |
| PostgreSQL | `20-ubuntu-pgsql`, `20-ubuntu`, `20` |
| PostgreSQL | `20-alpine-pgsql`, `20-alpine` |
| MySQL | `20-ubuntu-mysql`, `20-alpine-mysql` |

`bareos-client`, `bareos-storage`, and `bareos-webui`:

| base | tags |
|:--|:--|
| Ubuntu 24.04 | `25-ubuntu`, `25`, `ubuntu` |
| Ubuntu 24.04 | `24-ubuntu`, `24` |
| Ubuntu 22.04 | `23-ubuntu`, `23`, `22-ubuntu`, `22` |
| Alpine 3.18 | `22-alpine`, `alpine`, `latest` |
| Ubuntu 20.04 | `21-ubuntu`, `21`, `20-ubuntu`, `20` |
| Alpine | `21-alpine`, `20-alpine` |

`bareos-api`:

| base | tags |
|:--|:--|
| Alpine | `21-alpine`, `21`, `alpine`, `latest` |

The `api/22-alpine` and `api/24-alpine` directories are present in the source
tree, but they are not released because `bareos-restapi` is not available on
PyPI for those versions.

## Version Support

| Bareos version | Ubuntu image | Alpine image | Notes |
|:--|:--|:--|:--|
| 25 | `25-ubuntu` on Ubuntu 24.04 | not available | Installed from `download.bareos.org/current/` |
| 24 | `24-ubuntu` on Ubuntu 24.04 | not available | Installed from GitHub package release |
| 23 | `23-ubuntu` on Ubuntu 22.04 | not available | Installed from GitHub package release |
| 22 | `22-ubuntu` on Ubuntu 22.04 | `22-alpine` on Alpine 3.18 | Ubuntu uses GitHub package release |
| 21 | `21-ubuntu` | `21-alpine` | Upstream versioned repo / Alpine package |
| 20 | `20-ubuntu` | `20-alpine` | Last version with MySQL backend |

Bareos removed the MySQL catalog backend in version 21. Use `director-mysql/*`
only for Bareos 20 or older and migrate existing MySQL catalogs to PostgreSQL
before upgrading past Bareos 20.

Bareos 23 removed the `dbdriver` directive from the catalog resource. If you
are upgrading from Bareos 22 or older, remove any `dbdriver = "postgresql"`
line from `/etc/bareos/bareos-dir.d/catalog/MyCatalog.conf` before starting
the Director. Leaving it in place causes a fatal config error:

```
bareos-dir: CONFIG ERROR at lib/parse_conf_state_machine.cc:161
Config error: Keyword "dbdriver" not permitted in this resource.
```

## Package Releases

`download.bareos.org/current/` tracks the latest Bareos release and does not
provide pinned 22, 23, or 24 Ubuntu repositories. This repo builds pinned `.deb`
packages from upstream Bareos release tags and publishes them as GitHub Release
assets.

The Ubuntu 22/23/24 Dockerfiles consume the package release
`pkg/bareos-packages-v1`:

| asset | used by |
|:--|:--|
| `bareos-22-jammy.tar.gz` | `22-ubuntu` component images |
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
| [docker-compose-alpine-mysql.yml][compose-alpine-mysql-href] | MySQL | legacy, Bareos 20 or older |
| [docker-compose-alpine-mysql-v2.yml][compose-alpine-mysql-v2-href] | MySQL | legacy, Bareos 20 or older |
| [docker-compose-ubuntu-mysql.yml][compose-ubuntu-mysql-href] | MySQL | legacy, Bareos 20 or older |

The compose examples store data under `/data/(bareos|mysql|pgsql)`.

## Access

Web UI:

```text
http://your-docker-host:8080
```

Default user is `admin`; the password is `BAREOS_WEBUI_PASSWORD`.

Bareos console:

```bash
docker exec -it bareos-dir bconsole
```

REST API docs:

```text
http://your-docker-host:8000/docs
```

Prometheus metrics:

```text
http://your-docker-host:9625/metrics
```

Metrics are provided by [bareos_exporter][bareos-exporter-href] and should be
scraped by [Prometheus][prometheus-href].

## Database Migration

Bareos 21 and newer do not ship the MySQL catalog backend. To migrate an
existing MySQL catalog, upgrade to Bareos 20 first, then use the
[database migration compose file][compose-db-migration-href] to copy the
catalog into PostgreSQL.

If the target PostgreSQL database is empty or does not exist, the migration
tool creates it. Keep `.env` available with the required database passwords.

## Building Images

Build a specific component/version:

```bash
docker build -t bareos-director:24-ubuntu director-pgsql/24-ubuntu
docker build -t bareos-storage:24-ubuntu storage/24-ubuntu
docker build -t bareos-client:24-ubuntu client/24-ubuntu
docker build -t bareos-webui:24-ubuntu webui/24-ubuntu
docker build -t bareos-api:21-alpine api/21-alpine
```

For Ubuntu 22/23/24 images, the package release assets must exist before the
build can download them.

## Links

* [Bareos documentation][bareos-doc]
* [director-pgsql][repo-director-pgsql]
* [director-mysql][repo-director-mysql]
* [storage][repo-storage]
* [client][repo-client]
* [webui][repo-webui]
* [api][repo-api]

[arch-amd64-img]: https://img.shields.io/badge/arch-amd64-inactive
[arch-arm64/v8-img]: https://img.shields.io/badge/arch-arm64/v8-inactive
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
[compose-alpine-mysql-href]: https://github.com/Dark-Vex/bareos/blob/master/docker-compose-alpine-mysql.yml
[compose-alpine-mysql-v2-href]: https://github.com/Dark-Vex/bareos/blob/master/docker-compose-alpine-mysql-v2.yml
[compose-ubuntu-mysql-href]: https://github.com/Dark-Vex/bareos/blob/master/docker-compose-ubuntu-mysql.yml
[compose-ubuntu-pgsql-href]: https://github.com/Dark-Vex/bareos/blob/master/docker-compose-ubuntu-pgsql.yml
[compose-db-migration-href]: https://github.com/Dark-Vex/bareos/blob/master/bareos-db-migration/docker-compose.yml
[docker-compose-href]: https://docs.docker.com/compose
[docker-href]: https://docs.docker.com/engine/install/
[docker-img-dir]: https://img.shields.io/docker/pulls/barcus/bareos-director?label=bareos-director&logo=docker
[docker-img-fd]: https://img.shields.io/docker/pulls/barcus/bareos-client?label=bareos-client&logo=docker
[docker-img-sd]: https://img.shields.io/docker/pulls/barcus/bareos-storage?label=bareos-storage&logo=docker
[docker-img-ui]: https://img.shields.io/docker/pulls/barcus/bareos-webui?label=bareos-webui&logo=docker
[docker-img-api]: https://img.shields.io/docker/pulls/barcus/bareos-api?label=bareos-api&logo=docker
[docker-url-dir]: https://registry.hub.docker.com/r/barcus/bareos-director
[docker-url-fd]: https://registry.hub.docker.com/r/barcus/bareos-client
[docker-url-sd]: https://registry.hub.docker.com/r/barcus/bareos-storage
[docker-url-ui]: https://registry.hub.docker.com/r/barcus/bareos-webui
[docker-url-api]: https://registry.hub.docker.com/r/barcus/bareos-api
[license-img]: https://img.shields.io/badge/License-MIT-yellow.svg
[os-based-alpine]: https://img.shields.io/badge/os-alpine-9cf
[os-based-ubuntu]: https://img.shields.io/badge/os-ubuntu-9cf
[prometheus-href]: https://prometheus.io
[bareos-exporter-href]: https://github.com/vierbergenlars/bareos_exporter
[repo-api]: https://github.com/Dark-Vex/bareos/tree/master/api
[repo-client]: https://github.com/Dark-Vex/bareos/tree/master/client
[repo-director-mysql]: https://github.com/Dark-Vex/bareos/tree/master/director-mysql
[repo-director-pgsql]: https://github.com/Dark-Vex/bareos/tree/master/director-pgsql
[repo-storage]: https://github.com/Dark-Vex/bareos/tree/master/storage
[repo-webui]: https://github.com/Dark-Vex/bareos/tree/master/webui
[size-alpine-client-png]: https://img.shields.io/docker/image-size/barcus/bareos-client/alpine?label=alpine&style=plastic
[size-alpine-director-png]: https://img.shields.io/docker/image-size/barcus/bareos-director/alpine?label=alpine&style=plastic
[size-alpine-storage-png]: https://img.shields.io/docker/image-size/barcus/bareos-storage/alpine?label=alpine&style=plastic
[size-alpine-webui-png]: https://img.shields.io/docker/image-size/barcus/bareos-webui/alpine?label=alpine&style=plastic
[size-latest-client-png]: https://img.shields.io/docker/image-size/barcus/bareos-client/latest?label=latest&style=plastic
[size-latest-director-png]: https://img.shields.io/docker/image-size/barcus/bareos-director/latest?label=latest&style=plastic
[size-latest-storage-png]: https://img.shields.io/docker/image-size/barcus/bareos-storage/latest?label=latest&style=plastic
[size-latest-webui-png]: https://img.shields.io/docker/image-size/barcus/bareos-webui/latest?label=latest&style=plastic
[size-latest-api-png]: https://img.shields.io/docker/image-size/barcus/bareos-api/latest?label=latest&style=plastic
