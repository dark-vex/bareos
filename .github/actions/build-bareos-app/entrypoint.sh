#!/usr/bin/env bash

workdir="${GITHUB_WORKSPACE}/build"
export DOCKER_CLI_EXPERIMENTAL="enabled"

# Load buildx binary
echo ::group::Load Buildx
mkdir -vp ~/.docker/cli-plugins/ ~/dockercache
cp "${workdir}/docker-buildx" ~/.docker/cli-plugins/
chmod a+x ~/.docker/cli-plugins/docker-buildx
echo ::endgroup::

# Create build context and build
echo ::group::Create build context
docker buildx create --use
echo ::endgroup::

# Build from app_build.txt
echo ::group::Build Bareos
HAS_ERROR=0
while read app version arch app_path ; do
  tag="${version}"
  re='^[0-9]+-alpine.*$'
  if [[ $version =~ $re ]] ; then
    tag="${version}-${arch}"
  fi

  # Build with buildx
  docker buildx build \
    --no-cache \
    --platform "linux/${arch}" \
    --build-arg VERSION=$(echo "$version" |cut -d'-' -f1) \
    --build-arg VCS_REF=$(git rev-parse --short HEAD) \
    --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
    --build-arg NAME="${GITHUB_REPOSITORY}-${app}" \
    --tag "bareos-${app}:${tag}" \
    --output "type=docker,dest=${workdir}/bareos-${app}-${tag}.tar" \
    "${app_path}"

  if [[ $? -ne 0 ]] ; then
    echo "::error:: ERROR-build: failed ${GITHUB_REPOSITORY}-${app}:${tag} in ${app_path}"
    rm -f "${workdir}/bareos-${app}-${tag}.tar"
    HAS_ERROR=1
  fi

done < "${workdir}/app_build.txt"
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
