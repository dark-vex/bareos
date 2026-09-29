#!/usr/bin/env bash

workdir="${GITHUB_WORKSPACE}/build"
build_file="${INPUT_BUILD_FILE:-app_build.txt}"
BUILDX_VER='v0.5.1'
export DOCKER_CLI_EXPERIMENTAL="enabled"

# Install the buildx binary matching the native runner architecture.
echo ::group::Install Buildx
case "$(uname -m)" in
  x86_64)
    buildx_arch='amd64'
    ;;
  aarch64|arm64)
    buildx_arch='arm64'
    ;;
  *)
    echo "::error:: Unsupported runner architecture: $(uname -m)"
    exit 1
    ;;
esac
mkdir -vp ~/.docker/cli-plugins/ ~/dockercache
buildx_url="https://github.com/docker/buildx/releases/download/${BUILDX_VER}/buildx-${BUILDX_VER}.linux-${buildx_arch}"
curl --fail --silent --show-error -L "${buildx_url}" \
  --output ~/.docker/cli-plugins/docker-buildx
chmod a+x ~/.docker/cli-plugins/docker-buildx
echo ::endgroup::

# Create build context and build
echo ::group::Create build context
docker buildx create --use
echo ::endgroup::

# Build from app_build.txt
echo ::group::Build Bareos
HAS_ERROR=0
while read -r app version arch app_path ; do
  tag="${version}"
  re='^[0-9]+-alpine.*$'
  if [[ $version =~ $re ]] ; then
    tag="${version}-${arch}"
  fi

  # Build with buildx
  if ! docker buildx build \
    --no-cache \
    --pull \
    --platform "linux/${arch}" \
    --build-arg VERSION="$(echo "$version" | cut -d'-' -f1)" \
    --build-arg VCS_REF="$(git rev-parse --short HEAD)" \
    --build-arg BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
    --build-arg NAME="${GITHUB_REPOSITORY}-${app}" \
    --tag "bareos-${app}:${tag}" \
    --output "type=docker,dest=${workdir}/bareos-${app}-${tag}.tar" \
    "${app_path}" ; then
    echo "::error:: ERROR-build: failed ${GITHUB_REPOSITORY}-${app}:${tag} in ${app_path}"
    rm -f "${workdir}/bareos-${app}-${tag}.tar"
    HAS_ERROR=1
  fi

done < "${workdir}/${build_file}"
echo ::endgroup::

# Clean & fix perm
echo ::group::Clean
docker buildx rm
if [[ $HAS_ERROR -ne 0 ]]; then
  exit 1
fi
find "${workdir}" -name 'bareos-*.tar' -exec chmod 755 {} +
echo ::endgroup::

#EOF
