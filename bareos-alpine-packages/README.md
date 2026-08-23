# bareos-alpine-packages — aarch64 Bareos .apk builder

Builds Bareos `.apk` packages for `aarch64` (arm64/v8) from Alpine's own
`community/bareos` APKBUILD, for the Alpine branches whose upstream `arch=` line does
not include `aarch64`.

## Why

Alpine's `community/bareos` package is actively maintained and tracks upstream Bareos —
it just freezes at whatever version was current when each Alpine stable branch cut, and
`arch=` on 3.21/3.22/3.23/3.24 dropped `aarch64` (it was present through 3.18). amd64 is
always covered upstream; armv7 is covered upstream only through 3.22 (Bareos 24.0.1).
This builder covers the aarch64 gap the same way `bareos-packages/` covers the Ubuntu
source-build gap — by building the *unmodified* upstream package recipe ourselves,
minus the one build-time-only dependency (`chromium-chromedriver`) that keeps `arch=`
pinned, and extending `arch=` to include `aarch64`.

| Artifact bucket           | Alpine branch | Bareos version | Upstream aarch64? |
|----------------------------|---------------|-----------------|--------------------|
| bareos-23-alpine3.21       | 3.21-stable   | 23.0.4-r1       | no — build here    |
| bareos-24-alpine3.23       | 3.23-stable   | 24.0.7-r0       | no — build here    |
| bareos-25-alpine3.24       | 3.24-stable   | 25.0.3-r0       | no — build here    |

**armv7 is intentionally not built here for bareos_version 24/25.** A real upstream
bug — not a missing dependency — blocks it: `core/src/plugins/filed/python/module/bareosfd.h`
gates `static_assert(std::is_same_v<decltype(PyStatPacket::atime), long>)` only on
`#if defined(HAVE_WIN32)`. On 32-bit ARM/musl, `time_t` is the Y2038-safe 64-bit type,
so the assert fails there too, the same way it would on Windows if that branch weren't
special-cased. Confirmed via real `abuild -r` spikes against both Release/24.0.7 and
Release/25.0.3 on 2026-08-22 (both fail identically). `-DENABLE_PYTHON=no` is not a
clean workaround — it breaks the `bareos_add_plugin` CMake macro used by the (unrelated)
storage plugin, and would ship armv7 with a different feature set than every other arch,
defeating the whole point of building upstream's own unmodified recipe. armv7 for
bareos-23 (3.21-stable) is unaffected and needs no custom build — it installs straight
from Alpine's official repo, see the component Dockerfiles.

## Why aarch64 is safe to add back (investigated, not assumed)

The `arch=` line on every affected branch is preceded by the comment
`# chromium-chromedriver only present on these arches`. `chromium-chromedriver` is a
build-time-only `makedepends` entry that does not appear anywhere in the `build()`
function, and there is no `check()` function at all (`options="!check net"` disables
tests entirely) — the dependency looks vestigial for a test phase Alpine no longer runs.
Confirmed empirically: a real native `abuild -r` of Release/25.0.3 with aarch64 added to
`arch=` compiled clean in about a minute and produced every subpackage, including with
`chromium-chromedriver` still resolvable for aarch64 (it turned out to actually be
available there too — the removal is for build hygiene/speed, not because leaving it in
breaks anything).

## Build locally

```bash
docker build --platform linux/arm64 -f Dockerfile.builder.3.24 -t bareos-alpine-builder:3.24 .

mkdir -p ../artifacts
docker run --rm --platform linux/arm64 \
  -v "$(pwd)/../artifacts:/artifacts" \
  -e ALPINE_BRANCH=3.24-stable \
  -e BAREOS_VERSION=25 \
  bareos-alpine-builder:3.24

ls ../artifacts/bareos-25-alpine3.24/aarch64/
```

Replace `3.24`, `3.24-stable`, and `25` with the matching matrix values (see
`matrix.yml`) for the other two cells. Building runs under QEMU emulation unless your
host is natively arm64 (e.g. Apple Silicon) — expect single-digit minutes native,
several minutes to ~1 hour under emulation on a shared CI runner.

## CI / GitHub Actions

Workflow: `.github/workflows/build-bareos-alpine-packages.yml`

- **Manual trigger** (`workflow_dispatch`): builds all three matrix cells.
- **Scheduled**: Sundays at 04:00 UTC to rebuild against the pinned aports branches.
- **On push** to `bareos-alpine-packages/**`: rebuilds on builder file changes.

Artifacts are uploaded (30-day retention) as `apks-bareos-<version>-alpine-aarch64`.

## Publishing a GitHub Release

Tag the repo with `pkg/bareos-alpine-packages-vN` after a successful workflow run. The
`release` job rebuilds the matrix and attaches a per-version tarball to the same
GitHub Release:

```bash
git tag pkg/bareos-alpine-packages-v2
git push origin pkg/bareos-alpine-packages-v2
```

## Consuming packages in component Dockerfiles

Once a release exists, component Dockerfiles install from it on `aarch64` only — amd64
(and, for bareos-23 only, armv7) install straight from Alpine's community repo:

```dockerfile
ARG BAREOS_APK_RELEASE=pkg%2Fbareos-alpine-packages-v2
ARG BAREOS_APK_REPO=https://github.com/Dark-Vex/bareos
ARG BAREOS_APK_VER=25-alpine3.24

RUN apk add --no-cache curl \
 && curl -fsSL "${BAREOS_APK_REPO}/releases/download/${BAREOS_APK_RELEASE}/bareos-${BAREOS_APK_VER}-aarch64.tar.gz" -o /tmp/bareos-apks.tar.gz \
 && mkdir -p /tmp/bareos-apks && tar -xzf /tmp/bareos-apks.tar.gz -C /tmp/bareos-apks \
 && apk add --no-cache --allow-untrusted \
    /tmp/bareos-apks/bareos-[0-9]*.apk \
    /tmp/bareos-apks/bareos-libs-*.apk \
    /tmp/bareos-apks/bareos-filedaemon-*.apk
```

**`bareos-libs-*.apk` is required alongside the base `bareos-[0-9]*.apk` package** — the
base package and every daemon subpackage link against `so:libbareos.so.<ver>` etc.,
which live in the separate `bareos-libs` subpackage. Omitting it produces an
`unable to select packages` dependency error at install time (verified).

Package names per component (matches the upstream APKBUILD's `subpackages=`):

| Component      | `.apk` packages to install (plus `bareos-[0-9]*.apk` + `bareos-libs-*.apk`) |
|-----------------|------------------------------------------------------------------------|
| client (fd)     | `bareos-filedaemon-*.apk`                                               |
| storage (sd)    | `bareos-storage-*.apk`                                                  |
| director-pgsql  | `bareos-postgresql-*.apk` (bareos-23 only — folded into base from 24+) |
| webui           | `bareos-webui-[0-9]*.apk` `bareos-webui-nginx-*.apk`                    |

## Notes

- The APKBUILD patch (drop `chromium-chromedriver`, extend `arch=`) is applied at
  container run time in `build.sh`, against a fresh sparse checkout of the matching
  aports branch — not committed here — so it always tracks whatever the branch's
  APKBUILD currently says instead of a stale copy.
- Use the `.claude/skills/add-bareos-version` skill's `references/upstream-sources.md`
  for the full verified arch/version/subpackage matrix before generating new component
  directories from a release published here.
