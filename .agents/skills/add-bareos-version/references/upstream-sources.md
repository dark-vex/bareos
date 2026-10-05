# Bareos Upstream Source Table

Last verified: 2026-06-01

## Ubuntu repos

| Bareos version | Ubuntu base | BAREOS_KEY | BAREOS_REPO | Status |
|---------------|-------------|------------|-------------|--------|
| 20 | ubuntu:focal (20.04) | `http://download.bareos.org/bareos/release/20/xUbuntu_20.04/Release.key` | `http://download.bareos.org/bareos/release/20/xUbuntu_20.04/` | ✓ versioned |
| 21 | ubuntu:focal (20.04) | `http://download.bareos.org/bareos/release/21/xUbuntu_20.04/Release.key` | `http://download.bareos.org/bareos/release/21/xUbuntu_20.04/` | ✓ versioned |
| 22 | ubuntu:jammy (22.04) | `http://download.bareos.org/current/xUbuntu_22.04/Release.key` | `http://download.bareos.org/current/xUbuntu_22.04/` | ⚠ current/ installs latest Bareos (25.x as of 2026-04); **deprecated by this fork** — existing `22-*` tags stay published but frozen, no longer built or patched (see CLAUDE.md's Version Support section) |
| 23 | — | — | — | ✗ no versioned repo; current/ does not pin to 23 |
| 24 | ubuntu:noble (24.04) | `http://download.bareos.org/current/xUbuntu_24.04/Release.key` | `http://download.bareos.org/current/xUbuntu_24.04/` | ⚠ current/ installs latest Bareos (25.x as of 2026-04) |
| 25 | ubuntu:noble (24.04) | `http://download.bareos.org/current/xUbuntu_24.04/Release.key` | `http://download.bareos.org/current/xUbuntu_24.04/` | ⚠ current/ installs latest Bareos (25.x as of 2026-06); 25-ubuntu images built from this |

**Note**: For v22+, `current/` always tracks the latest Bareos release. The directory name reflects Ubuntu version, not Bareos version.

## Alpine repos

Alpine's `community/bareos` package is actively maintained and tracks upstream Bareos —
it just freezes at whatever version was current when each Alpine stable branch cut, like
any distro backport. Verified 2026-08-22 via `docker run --rm --platform <arch> alpine:<tag> apk search -e bareos`
against the live Alpine CDN (see Verification commands below).

| Bareos version | Alpine tag | Bareos package | amd64 | aarch64 | `bareos-postgresql` subpackage? |
|---------------|-----------|----------------|:---:|:---:|---|
| 20 | alpine:3.15 | bareos-20.x | ✓ | — | yes |
| 21 | alpine:3.17 | bareos-21.x | ✓ | — | yes |
| 22 | alpine:3.18 | bareos-22.0.3-r1 | ✓ | ✓ | yes (deprecated by this fork — frozen, see CLAUDE.md) |
| 23 | alpine:3.21 | bareos-23.0.4-r1 | ✓ | ✗ needs custom build | yes |
| 24 | alpine:3.23 | bareos-24.0.7-r0 | ✓ | ✗ needs custom build | no — folded into base `bareos` |
| 25 | alpine:3.24 | bareos-25.0.3-r0 | ✓ | ✗ needs custom build | no — folded into base `bareos` |

**Notes**:

- `bareos-storage`, `bareos-filedaemon`, `bareos-webui-nginx` subpackage names are stable
  across all branches above; confirmed present alongside `bareos` on every branch tested.
- From Bareos 24 (Alpine 3.22+) the postgres catalog driver (`bareos-fd-postgresql.py`,
  postgres DDL scripts, `libbareossql`) ships inside the base `bareos` package — there is
  no separate `bareos-postgresql` subpackage to install for director-pgsql on 23+/24/25.
  23 (Alpine 3.21) still has the separate `bareos-postgresql` subpackage.
- **24-alpine base is 3.23, not 3.22.** This repo deliberately chose the fresher 3.23 base
  (24.0.7-r0) over the older 3.22 (24.0.1-r0) and accepted that aarch64 needs a custom build
  for 24-alpine — same effort profile as 25-alpine. Do not "fix" this back to 3.22 without
  checking with the user first; it was an explicit tradeoff decision.
- aarch64 (`linux/arm64/v8`) was dropped from Alpine's `arch=` after 3.18 for 23/24/25.
  Investigated, not just observed: the APKBUILD's `arch=` line on 3.22/3.24 is preceded by
  a comment tying the restriction to `chromium-chromedriver`, a build-time-only
  `makedepends` entry that does not appear anywhere in the `build()` function (there is no
  `check()` function either — `options="!check net"` disables tests). Every other build
  dependency was spot-checked as available for aarch64 on Alpine 3.24. This is evidence the
  restriction is vestigial, not proof — Alpine's own builders never attempted aarch64 once
  `arch=` excluded it. A real spike (`abuild -r` under `--platform linux/arm64`) is required
  before committing to a custom aarch64 build; see the `add-bareos-version` plan's Step 0.

## api component (bareos-restapi pip package)

Verified 2026-09-03 against `https://pypi.org/pypi/bareos-restapi/json`: PyPI
publishes releases for every Bareos version 21–25, so `api/N-alpine` dirs
exist for all five (21, 22, 23, 24, 25). PyPI availability is necessary but
**not sufficient** — see the import-check note below.

| Version | Pip spec | PyPI status | Import check |
|---------|----------|-------------|---------------|
| 21 | `>=21*,<22*` | ✓ 21.1.9 on PyPI | ✗ fails — see note |
| 22 | `>=22*,<23*` | ✓ 22.1.5 on PyPI | ✗ fails — see note |
| 23 | `>=23,<24` | ✓ 23.1.1 on PyPI | ✓ imports cleanly |
| 24 | `>=24,<25` | ✓ 24.0.11 on PyPI | ✓ imports cleanly |
| 25 | `>=25,<26` | ✓ 25.1.1 on PyPI | ✓ imports cleanly |

**api component note**: `pip install` succeeding is not enough — verified
2026-09-03 via `docker run --rm <image> python -c "import bareos_restapi"`.
21.x and 22.x's model code raises `PydanticSchemaGenerationError` at import
time because pip has no upper bound on `pydantic` and resolves to a v2
release those two can't parse; 23.x+ import cleanly. CI's own test step
(`.github/actions/test-bareos-app`) only checks `pip show` output, so it does
**not** catch this — the import must be checked manually. `api/21-alpine` and
`api/22-alpine` exist in the source tree but are excluded from CI
(`.github/actions/prepare-bareos-app/entrypoint.sh` now skips *all* apps for
versions `<= 22` — version 22 was separately deprecated by this fork, which
folded the api-specific `<= 22` skip into that general one; the pydantic
failure remains the standalone reason `api` would need to keep skipping 22
even if the general deprecation skip were ever narrowed) until this is fixed
upstream or the transitive deps are pinned.
`latest_api` in that same script tracks the api version that gets the bare
`N`/`alpine`/`latest` tags — currently `24`. Before generating a new api dir:
verify the pip spec resolves via `https://pypi.org/pypi/bareos-restapi/json`,
build it locally, **and** run the import check above — don't trust a
successful `pip install` alone.

**Base image / pip-spec syntax (re-verified 2026-09-08)**: `api/23-alpine`,
`api/24-alpine`, `api/25-alpine` now build `FROM python:3.14-alpine`
(bumped from `python:3.10-alpine` — Python 3.10 reaches upstream EOL
2026-10-31, and 3.14 also carries the fix for CVE-2026-4519, a stdlib
`webbrowser` command-injection bug fixed in 3.13.13/3.14.4 that scanners flag
against 3.10.x — confirmed via the Debian security tracker, not just the
plan that proposed this bump. CVE-2026-4519 also had a follow-up incomplete-
mitigation bug, CVE-2026-4786, fully fixed starting 3.14.5rc1; the image here
resolves to 3.14.7, so both are covered. The `pip install --upgrade
pip==22.0.4` line was dropped —
the base image's bundled pip is already current. Dropping that pin surfaced
a real bug: the wildcard version-specifier syntax these Dockerfiles used
(`>=23*,<24*`) is not valid PEP 440 and modern pip (the kind bundled with any
current base image, independent of the Python version) rejects it outright
with `ERROR: Invalid requirement`. Old pip 22.0.4 tolerated it via a legacy
parser. Fixed by dropping the wildcards (`>=23,<24`) — confirmed to resolve
to the identical version (e.g. 23.1.1) as the old syntax did under pip
22.0.4, since no 23.x/24.x/25.x release on PyPI uses a non-standard version
string. **`api/21-alpine` and `api/22-alpine` still use the old `>=21*,<22*`
wildcard syntax and were deliberately left untouched** (already excluded
from CI, already broken on import, would get zero verification from this
spike) — fix their pip spec too if either is ever un-blocked. All three
bumped versions were verified (build, `import bareos_restapi`, `which
uvicorn`, and a live `uvicorn --reload` serving `/docs`) on amd64 and arm64.
These Dockerfiles install bare `uvicorn`, not `uvicorn[standard]`, so
`--reload` uses uvicorn's `StatReload` fallback and never pulls in
`watchfiles` at all.

**Base image digest refresh (re-verified 2026-10-05)**: `api/23-alpine`,
`api/24-alpine`, `api/25-alpine` bumped the `python:3.14-alpine` digest from
`sha256:9e9fde4d32eedce0b661d9ab91e826b62dddf28e928c230ec55f1866cac66b01`
(`3.14.7-alpine3.24`) to
`sha256:f6a589d43c42b9e7f7dc67a12d37132491f362859a5d750607710cc56da3bc72`
(`3.14.8-alpine3.24`), fixing CVE-2026-19445 (CRITICAL, public exploit)
flagged by the Wiz `deploy` job's weekly scheduled scan against all six
`api/{23,24,25}-alpine` × `{amd64,arm64}` build tags. Same-tag,
same-Alpine-base, Python-patch-only refresh — confirmed via `docker buildx
imagetools inspect python:3.14-alpine` (index covers both `linux/amd64` and
`linux/arm64/v8`, both still built on `alpine:3.24`) and by running the pulled
image directly (`python3 --version` → `3.14.8`; `cat /etc/alpine-release` →
`3.24.2`), then re-confirmed on the final built `api` image (each Dockerfile
runs `apk upgrade --no-cache`, which doesn't change these numbers here).

Separately, the `requirements.txt` in each of these three directories was
regenerated with `pip-compile --generate-hashes --strip-extras
--upgrade-package fastapi==0.142.2 -o requirements.txt requirements.in`
(Python 3.14.8, Alpine Linux 3.24.2, pip-tools 7.6.1) to unblock a Dependabot
PR that bumped `fastapi` 0.141.1→0.142.2 but produced an incomplete/
inconsistent lockfile: FastAPI 0.142.2 unconditionally introduces
`opentelemetry-api>=1.44.0` as a new dependency, which Dependabot's
patch-style update doesn't add in `--require-hashes` mode, and that PR
separately bumped `pydantic-core` to `2.49.0` while leaving `pydantic` at
`2.13.5` — whose published metadata requires `pydantic-core==2.46.5` exactly,
an inconsistent pin. Letting the resolver run (rather than forcing either
value) picked up `opentelemetry-api==1.45.0` and kept `pydantic-core==2.46.5`,
the only version `pydantic==2.13.5` is actually compatible with. Verified per
version/arch: `pip install --require-hashes` succeeds (build fails
otherwise, since that's a `RUN` step in the Dockerfile), `pip check` reports
no broken requirements, installed versions match
(`fastapi==0.142.2`/`opentelemetry-api==1.45.0`/`pydantic==2.13.5`/
`pydantic_core==2.46.5`), and a running container serves `/docs` with
`HTTP 200` — all on both `linux/amd64` and `linux/arm64/v8`.

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

## Still missing (as of 2026-09-16)

Every version/flavor combination identified as "missing and buildable" in an
earlier pass of this table (23/24/25-alpine, 23/24-ubuntu, 25-ubuntu, for
director-pgsql/storage/client/webui) has since been generated and built —
check the component directories directly rather than this file for current
coverage. What's still genuinely unbuildable:

| Component | Target | Buildable? | Reason |
|-----------|--------|------------|--------|
| api | 20-alpine | ✗ | bareos-restapi<21 not on PyPI |
| director-mysql | 21+ | ✗ | MySQL backend dropped in Bareos 21+ |
| `*/22-*` | any new build | ✗ (by policy) | Bareos 22 deprecated by this fork — existing dirs stay, but excluded from CI; see CLAUDE.md's Version Support section |
