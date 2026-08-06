#!/usr/bin/env bash

workdir="${GITHUB_WORKSPACE}/build"
docker_files=$(find "${workdir}/" -name "bareos-*.tar" 2>/dev/null)
rm_tag=""

# Enable experimental feature in Docker
export DOCKER_CLI_EXPERIMENTAL="enabled"

# Strip any http/https scheme prefix and trailing slash
registry="${INPUT_REGISTRY#https://}"
registry="${registry#http://}"
registry="${registry%/}"
registry="${registry%%[[:space:]]}"

# Load Dockerfiles
echo ::group::Load Dockerfile
echo "${docker_files}"
for file in $docker_files; do
  docker load --input "$file"
done
echo ::endgroup::

# Connect Docker Hub
docker login "${registry}" -u "${INPUT_DOCKER_USER}" -p "${INPUT_DOCKER_PASS}"

# Push tags and manfiests
echo ::group::Push build tags
while read line ; do
  app=$(echo $line|awk '{print $1}')
  version=$(echo $line|awk '{print $2}')
  arch=$(echo $line|awk '{print $3}')
  build_tag=${version}
  img_prefix="${INPUT_IMAGE_PREFIX:-${registry}/${GITHUB_REPOSITORY}}"
  re='^[0-9]+-alpine.*$'
  if [[ $version =~ $re ]] ; then
    build_tag="${version}-${arch}"
    rm_tag="$rm_tag ${img_prefix}-${app}:${build_tag}"
  fi
  # Re-tag local image with registry-qualified name then push
  local_name="bareos-${app}:${build_tag}"
  remote_name="${img_prefix}-${app}:${build_tag}"
  docker tag "${local_name}" "${remote_name}"
  docker push "${remote_name}"
done < "${workdir}/app_build.txt"
echo ::endgroup::

echo ::group::Push additional tags
while read build_app s_tag t_tag ; do
  img_prefix="${INPUT_IMAGE_PREFIX:-${registry}/${GITHUB_REPOSITORY}}"
  # Push additional tags for Ubuntu
  if [[ $s_tag =~ ^[a-z0-9]+-ubuntu.*$ ]]; then
    docker tag "${img_prefix}-${build_app}:${s_tag}" \
      "${img_prefix}-${build_app}:${t_tag}"
    docker push "${img_prefix}-${build_app}:${t_tag}"
  fi
  # Create and push manifest for Alpine (arm64 + amd64)
  if [[ $s_tag =~ ^[a-z0-9]+-alpine.*$ ]]; then
    docker manifest create "${img_prefix}-${build_app}:${t_tag}" \
      "${img_prefix}-${build_app}:${s_tag}-amd64" \
      "${img_prefix}-${build_app}:${s_tag}-arm64"
    docker manifest push "${img_prefix}-${build_app}:${t_tag}"
  fi
done < "${workdir}/tag_build.txt"
echo ::endgroup::

# Clean Alpine build_tag (amd/arm)
echo ::group::Clean
if [[ -n "${rm_tag}" ]]; then
  docker run --rm lumir/remove-dockerhub-tag \
    --user "${GITHUB_ACTOR}" --password ${INPUT_DOCKER_PASS} ${rm_tag}
fi
echo ::endgroup::

#EOF
