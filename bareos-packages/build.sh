#!/usr/bin/env bash
set -euo pipefail

BAREOS_BRANCH="${BAREOS_BRANCH:?BAREOS_BRANCH env var required (e.g. bareos-22)}"
UBUNTU_CODENAME="${UBUNTU_CODENAME:?UBUNTU_CODENAME env var required (e.g. jammy)}"
ARTIFACTS_DIR="/artifacts/${BAREOS_BRANCH}/${UBUNTU_CODENAME}"

echo "==> Cloning ${BAREOS_BRANCH} ..."
git clone --depth 1 --branch "${BAREOS_BRANCH}" \
    https://github.com/bareos/bareos.git /src

cd /src

if [ ! -f debian/changelog ]; then
    VERSION="${BAREOS_BRANCH#bareos-}.0.0~localsrc"
    echo "==> Generating debian/changelog (${VERSION}) ..."
    DEBEMAIL="builder@localhost" DEBFULLNAME="Local Builder" \
        dch --create --empty \
            --package bareos \
            --newversion "${VERSION}" \
            --distribution "${UBUNTU_CODENAME}" \
            "Local build from source branch ${BAREOS_BRANCH}"
fi

echo "==> Installing build dependencies ..."
apt-get update -qq

case "${BAREOS_BRANCH}" in
    bareos-23)
        echo "==> Installing Qt5 Widgets for tray-monitor (v23) ..."
        apt-get install -qq -y --no-install-recommends \
            qtbase5-dev qttools5-dev qtbase5-dev-tools libqt5widgets5
        ;;
    bareos-24)
        echo "==> Installing Qt5 + gRPC + CPM-satisfying system packages (v24) ..."
        apt-get install -qq -y --no-install-recommends \
            qtbase5-dev qttools5-dev qtbase5-dev-tools libqt5widgets5 \
            libcli11-dev libfmt-dev libmsgsl-dev \
            libutfcpp-dev libxxhash-dev libgtest-dev libgmock-dev \
            libprotobuf-dev protobuf-compiler protobuf-compiler-grpc \
            libgrpc++-dev libgrpc-dev \
            libtirpc-dev libnsl-dev

        echo "==> Stubbing pg_ctl (systemtests CMakeLists requires it; tests not run) ..."
        printf '#!/bin/sh\n' > /usr/local/bin/pg_ctl && chmod +x /usr/local/bin/pg_ctl

        echo "==> Building tl-expected from source (no noble package) ..."
        git clone --depth 1 --branch v1.1.0 \
            https://github.com/TartanLlama/expected.git /tmp/tl-expected
        cmake -S /tmp/tl-expected -B /tmp/tl-expected/build \
            -DCMAKE_INSTALL_PREFIX=/usr -DEXPECTED_BUILD_TESTS=OFF
        cmake --install /tmp/tl-expected/build
        rm -rf /tmp/tl-expected
        ;;
esac

mk-build-deps \
    --install \
    --remove \
    --tool "apt-get -qq -y --no-install-recommends -o Debug::pkgProblemResolver=yes" \
    debian/control
rm -f /src/bareos-build-deps_*.deb

echo "==> Building packages (nocheck nodoc) ..."
DEB_BUILD_OPTIONS="nocheck nodoc parallel=$(nproc)" \
    dpkg-buildpackage -us -uc -b

echo "==> Collecting artifacts ..."
mkdir -p "${ARTIFACTS_DIR}"
find / -maxdepth 1 -name "bareos*.deb" -exec cp {} "${ARTIFACTS_DIR}/" \;

echo "==> Done. Produced packages:"
ls -lh "${ARTIFACTS_DIR}/"
