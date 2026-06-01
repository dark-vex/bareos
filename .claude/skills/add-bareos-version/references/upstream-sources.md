# Bareos Upstream Source Table

Last verified: 2026-06-01

## Ubuntu repos

| Bareos version | Ubuntu base | BAREOS_KEY | BAREOS_REPO | Status |
|---------------|-------------|------------|-------------|--------|
| 20 | ubuntu:focal (20.04) | `http://download.bareos.org/bareos/release/20/xUbuntu_20.04/Release.key` | `http://download.bareos.org/bareos/release/20/xUbuntu_20.04/` | ✓ versioned |
| 21 | ubuntu:focal (20.04) | `http://download.bareos.org/bareos/release/21/xUbuntu_20.04/Release.key` | `http://download.bareos.org/bareos/release/21/xUbuntu_20.04/` | ✓ versioned |
| 22 | ubuntu:jammy (22.04) | `http://download.bareos.org/current/xUbuntu_22.04/Release.key` | `http://download.bareos.org/current/xUbuntu_22.04/` | ⚠ current/ installs latest Bareos (25.x as of 2026-04) |
| 23 | — | — | — | ✗ no versioned repo; current/ does not pin to 23 |
| 24 | ubuntu:noble (24.04) | `http://download.bareos.org/current/xUbuntu_24.04/Release.key` | `http://download.bareos.org/current/xUbuntu_24.04/` | ⚠ current/ installs latest Bareos (25.x as of 2026-04) |
| 25 | ubuntu:noble (24.04) | `http://download.bareos.org/current/xUbuntu_24.04/Release.key` | `http://download.bareos.org/current/xUbuntu_24.04/` | ⚠ current/ installs latest Bareos (25.x as of 2026-06); 25-ubuntu images built from this |

**Note**: For v22+, `current/` always tracks the latest Bareos release. The directory name reflects Ubuntu version, not Bareos version.

## Alpine repos

| Bareos version | Alpine tag | Bareos package | Status |
|---------------|-----------|----------------|--------|
| 20 | alpine:3.15 | bareos-20.x | ✓ in community |
| 21 | alpine:3.17 | bareos-21.x | ✓ in community |
| 22 | alpine:3.18 | bareos-22.0.3-r1 | ✓ in community |
| 23 | — | — | ✗ Alpine 3.19+ has no Bareos packages |
| 24 | — | — | ✗ Alpine 3.19+ has no Bareos packages |
| 25 | — | — | ✗ Alpine 3.19+ has no Bareos packages |

**Note**: Bareos is only available in Alpine through 3.18. There is no Alpine support for Bareos 23+.

## api component (bareos-restapi pip package)

| Version | Pip spec | PyPI status |
|---------|----------|-------------|
| 21 | `>=21*,<22*` | ✓ 21.1.9 on PyPI |
| 22 | `>=22*,<23*` | ✗ not on PyPI — build will fail |
| 24 | `>=24*,<25*` | ✗ not on PyPI — build will fail |

**api component note**: The existing api/22-alpine and api/24-alpine Dockerfiles have broken pip constraints. Only api/21-alpine is reliably buildable. Do not generate new api dirs without first verifying PyPI availability.

## Verification commands

```bash
# Ubuntu: check a specific version URL
curl -sfI "http://download.bareos.org/bareos/release/<v>/xUbuntu_20.04/Release.key" && echo "YES" || echo "NO"
curl -sfI "http://download.bareos.org/current/xUbuntu_22.04/Release.key" && echo "YES" || echo "NO"

# Alpine: check what Bareos version an Alpine tag ships
docker run --rm alpine:<tag> sh -c "apk update -q 2>/dev/null && apk search -e bareos"

# pip: check bareos-restapi versions
curl -sL "https://pypi.org/simple/bareos-restapi/" | grep -Eo 'bareos.restapi-[0-9]+\.[0-9]+\.[0-9]+' | sed 's/bareos.restapi-//'
```

## Missing and buildable as of 2026-04-18

| Component | Target | Buildable? | Reason |
|-----------|--------|------------|--------|
| director-pgsql | 22-ubuntu | ✓ | Ubuntu 22.04 + current/ |
| director-pgsql | 24-alpine | ✗ | No Alpine package for Bareos 24 |
| director-pgsql | 23-alpine/ubuntu | ✗ | No upstream source |
| director-pgsql | 25-ubuntu | ✓ | Ubuntu 24.04 + current/ |
| director-pgsql | 25-alpine | ✗ | No Alpine package for Bareos 25 |
| storage | 25-ubuntu | ✓ | Ubuntu 24.04 + current/ |
| client | 25-ubuntu | ✓ | Ubuntu 24.04 + current/ |
| webui | 25-ubuntu | ✓ | Ubuntu 24.04 + current/ |
| api | 20-alpine | ✗ | bareos-restapi<21 not on PyPI |
| api | 23-alpine | ✗ | No upstream source |
| api | 25-alpine | ✗ | No upstream source |
| director-mysql | 21+ | ✗ | MySQL backend dropped in Bareos 21+ |
