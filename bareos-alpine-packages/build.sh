#!/bin/sh
set -eu

ALPINE_BRANCH="${ALPINE_BRANCH:?ALPINE_BRANCH env var required (e.g. 3.24-stable)}"
BAREOS_VERSION="${BAREOS_VERSION:?BAREOS_VERSION env var required (e.g. 25)}"
ALPINE_TAG="${ALPINE_BRANCH%-stable}"
ARTIFACTS_DIR="/artifacts/bareos-${BAREOS_VERSION}-alpine${ALPINE_TAG}/aarch64"

echo "==> Cloning aports ${ALPINE_BRANCH} community/bareos ..."
git clone --depth 1 --branch "${ALPINE_BRANCH}" --filter=blob:none --sparse \
    https://gitlab.alpinelinux.org/alpine/aports.git /tmp/aports
cd /tmp/aports
git sparse-checkout set community/bareos

mkdir -p /home/builder/bareos
cp -r community/bareos/. /home/builder/bareos/
cd /home/builder/bareos

echo "==> Patching APKBUILD: drop chromium-chromedriver (build-time-only makedepend,"
echo "    not referenced anywhere in build() — see references/upstream-sources.md in"
echo "    the add-bareos-version skill for the investigation), extend arch= to aarch64."
sed -i '/^\tchromium-chromedriver$/d' APKBUILD
# Append aarch64 to whatever arch= already lists (e.g. "x86_64" or "x86_64 armv7"),
# rather than assuming an exact prior value — this differs per Alpine branch.
sed -i 's/^arch="\([^"]*\)"$/arch="\1 aarch64"/' APKBUILD
grep -qE '^arch="[^"]* aarch64"$' APKBUILD || {
  echo "ERROR: arch= patch did not apply — upstream APKBUILD format changed, update this script" >&2
  exit 1
}
if grep -qE '^\s*chromium-chromedriver\s*$' APKBUILD; then
  echo "ERROR: chromium-chromedriver makedepend still present after patch — update this script" >&2
  exit 1
fi

chown -R builder:builder /home/builder/bareos

echo "==> abuild-keygen + abuild -r as unprivileged builder user ..."
su builder -c "cd /home/builder/bareos && abuild-keygen -a -i -n && abuild -r"

echo "==> Collecting artifacts ..."
mkdir -p "${ARTIFACTS_DIR}"
find /home/builder/packages -name '*.apk' -exec cp {} "${ARTIFACTS_DIR}/" \;

echo "==> Done. Produced packages:"
ls -lh "${ARTIFACTS_DIR}/"
