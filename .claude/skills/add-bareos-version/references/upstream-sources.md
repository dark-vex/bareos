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

Alpine's `community/bareos` package is actively maintained and tracks upstream Bareos —
it just freezes at whatever version was current when each Alpine stable branch cut, like
any distro backport. Verified 2026-08-22 via `docker run --rm --platform <arch> alpine:<tag> apk search -e bareos`
against the live Alpine CDN (see Verification commands below).

| Bareos version | Alpine tag | Bareos package | amd64 | armv7 | aarch64 | `bareos-postgresql` subpackage? |
|---------------|-----------|----------------|:---:|:---:|:---:|---|
| 20 | alpine:3.15 | bareos-20.x | ✓ | — | — | yes |
| 21 | alpine:3.17 | bareos-21.x | ✓ | — | — | yes |
| 22 | alpine:3.18 | bareos-22.0.3-r1 | ✓ | — | ✓ | yes |
| 23 | alpine:3.21 | bareos-23.0.4-r1 | ✓ | ✓ (upstream) | ✗ needs custom build | yes |
| 24 | alpine:3.23 | bareos-24.0.7-r0 | ✓ | ✗ needs custom build | ✗ needs custom build | no — folded into base `bareos` |
| 25 | alpine:3.24 | bareos-25.0.3-r0 | ✓ | ✗ needs custom build | ✗ needs custom build | no — folded into base `bareos` |

**Notes**:

- `bareos-storage`, `bareos-filedaemon`, `bareos-webui-nginx` subpackage names are stable
  across all branches above; confirmed present alongside `bareos` on every branch tested.
- From Bareos 24 (Alpine 3.22+) the postgres catalog driver (`bareos-fd-postgresql.py`,
  postgres DDL scripts, `libbareossql`) ships inside the base `bareos` package — there is
  no separate `bareos-postgresql` subpackage to install for director-pgsql on 23+/24/25.
  23 (Alpine 3.21) still has the separate `bareos-postgresql` subpackage.
- **24-alpine base is 3.23, not 3.22.** Alpine 3.22 ships Bareos 24.0.1-r0 with armv7 still
  free (no custom build needed), but that's an older patch release. This repo deliberately
  chose the fresher 3.23 base (24.0.7-r0) and accepted that armv7 (like aarch64) needs a
  custom build for 24-alpine — same effort profile as 25-alpine. Do not "fix" this back to
  3.22 without checking with the user first; it was an explicit tradeoff decision.
- aarch64 (`linux/arm64/v8`) was dropped from Alpine's `arch=` after 3.18 for 23/24/25.
  Investigated, not just observed: the APKBUILD's `arch=` line on 3.22/3.24 is preceded by
  a comment tying the restriction to `chromium-chromedriver`, a build-time-only
  `makedepends` entry that does not appear anywhere in the `build()` function (there is no
  `check()` function either — `options="!check net"` disables tests). Every other build
  dependency was spot-checked as available for aarch64 on Alpine 3.24. This is evidence the
  restriction is vestigial, not proof — Alpine's own builders never attempted aarch64 once
  `arch=` excluded it. A real spike (`abuild -r` under `--platform linux/arm64`) is required
  before committing to a custom aarch64 build; see the `add-bareos-version` plan's Step 0.
- armv7 is a separate, already-proven target for 23-alpine only (upstream `arch=` covers it
  on 3.21). It does **not** cover 24 (with the 3.23 base chosen here) or 25 (3.24).
- **armv7 custom builds for Bareos 24/25 are currently BLOCKED, not just extra effort.**
  Confirmed via real `abuild -r` spikes (2026-08-22) against both Release/24.0.7 and
  Release/25.0.3: the file-daemon Python plugin
  (`core/src/plugins/filed/python/module/bareosfd.{h,cc}`) has
  `static_assert(std::is_same_v<decltype(PyStatPacket::atime), long>)` gated only on
  `#if defined(HAVE_WIN32)`. On 32-bit ARM/musl, `time_t` is 64-bit (Y2038-safe time64
  ABI) so `PyStatPacket::atime` is not plain `long` there either, and the assert fails
  the same way Windows would if it weren't special-cased — a genuine upstream source
  bug, present in both 24.0.7 and 25.0.3, not a missing/vestigial build dependency like
  the aarch64 case. `-DENABLE_PYTHON=no` does not cleanly route around it either: it
  breaks `bareos_add_plugin` for the (unrelated) storage plugin CMakeLists, an upstream
  CMake coupling, and would ship armv7 images with a different feature set than other
  arches regardless. aarch64 (arm64) is unaffected — confirmed via a clean native spike
  build of 25.0.3 with all subpackages produced. Do not generate armv7 Dockerfile paths
  for 24-alpine or 25-alpine until this is resolved upstream or a vetted source patch
  exists; ask before attempting one.

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
(`.github/actions/prepare-bareos-app/entrypoint.sh` skips `api` versions
`<= 22`) until this is fixed upstream or the transitive deps are pinned.
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
uvicorn`, and a live `uvicorn --reload` serving `/docs`) on amd64 and arm64;
`api/23-alpine` was also verified the same way on armv7 under QEMU (the
tightest musllinux wheel-coverage constraint, since it's the only api
version CI builds for that arch) — build succeeded with only `pyyaml`
compiling from source (`cp314-cp314-linux_armv7l` wheel, ~5s). That wheel
tag looks like a compiled C extension but isn't: no gcc/musl-dev is present
in the base image, and `yaml.__with_libyaml__` reads `False` at runtime on
that armv7 image — confirmed pure-Python fallback, not a real build-toolchain
risk. No other package needed a source build. `pydantic-core` (Rust-backed)
had a prebuilt `musllinux_1_1_armv7l` wheel for `cp314`. `watchfiles` was
never a concern —
these Dockerfiles install bare `uvicorn`, not `uvicorn[standard]`, so
`--reload` uses uvicorn's `StatReload` fallback and never pulls in
`watchfiles` at all.

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

## Missing and buildable as of 2026-08-22

| Component | Target | Buildable? | Reason |
|-----------|--------|------------|--------|
| director-pgsql | 22-ubuntu | ✓ | Ubuntu 22.04 + current/ |
| director-pgsql / storage / client / webui | 23-alpine | ✓ (amd64, armv7); arm64 pending spike | Alpine 3.21, upstream `bareos-23.0.4-r1`; arm64 needs a custom-built `.apk` |
| director-pgsql / storage / client / webui | 24-alpine | ✓ (amd64 only); armv7 + arm64 pending spike | Alpine 3.23, upstream `bareos-24.0.7-r0`; armv7 and arm64 both need custom-built `.apk`s |
| director-pgsql / storage / client / webui | 23/24-ubuntu | ✓ | Built from source via `bareos-packages/`, see its README |
| director-pgsql | 25-ubuntu | ✓ | Ubuntu 24.04 + current/ |
| director-pgsql / storage / client / webui | 25-alpine | ✓ (amd64 only); armv7 + arm64 pending spike | Alpine 3.24, upstream `bareos-25.0.3-r0`; armv7 and arm64 both need custom-built `.apk`s |
| storage | 25-ubuntu | ✓ | Ubuntu 24.04 + current/ |
| client | 25-ubuntu | ✓ | Ubuntu 24.04 + current/ |
| webui | 25-ubuntu | ✓ | Ubuntu 24.04 + current/ |
| api | 20-alpine | ✗ | bareos-restapi<21 not on PyPI |
| api | 23-alpine | ✗ | No upstream source |
| api | 25-alpine | ✗ | No upstream source |
| director-mysql | 21+ | ✗ | MySQL backend dropped in Bareos 21+ |

"Pending spike" arches install nothing until the Step 0 aarch64/armv7 build spike (see the
`add-bareos-version` plan) confirms a custom `.apk` can actually be built and a builder
pipeline publishes it — do not generate a Dockerfile that assumes an arch's `.apk` exists
without that artifact actually being available.
