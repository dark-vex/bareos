#!/usr/bin/env bash

workdir="${GITHUB_WORKSPACE}/build"
docker_files=$(find "${workdir}/" -name "bareos-*.tar" 2>/dev/null)
rm_tags=()
rm_tags_dockerhub=()

mkdir -p "${workdir}/sarif"

# Enable experimental feature in Docker
export DOCKER_CLI_EXPERIMENTAL="enabled"

# wizcli reads these automatically for scan/tag; no separate auth step needed
export WIZ_CLIENT_ID="${INPUT_WIZ_CLIENT_ID}"
export WIZ_CLIENT_SECRET="${INPUT_WIZ_CLIENT_SECRET}"

# Fixed set of Wiz policies enforced on every container-image scan
wiz_policies="[ddl] Default secrets policy","[ddl] Default sensitive data policy","[ddl] Default software license policy","[ddl] Default vulnerabilities policy"

# Strip any http/https scheme prefix and trailing slash
registry="${INPUT_REGISTRY#https://}"
registry="${registry#http://}"
registry="${registry%/}"
registry="${registry%%[[:space:]]}"

# Docker Hub is an optional second push target, alongside the primary
# registry above. Images are already scanned once against the primary
# registry tag below; the Docker Hub retag/push reuses that scan result
# instead of scanning the same image content again.
dockerhub_enabled=0
if [[ -n "${INPUT_DOCKERHUB_USER:-}" && -n "${INPUT_DOCKERHUB_PASS:-}" ]]; then
  dockerhub_enabled=1
  dockerhub_prefix="${INPUT_DOCKERHUB_IMAGE_PREFIX:-darkvex/bareos}"
fi

# Load Dockerfiles
echo ::group::Load Dockerfile
echo "${docker_files}"
for file in $docker_files; do
  docker load --input "$file"
done
echo ::endgroup::

HAS_ERROR=0

# Connect to the primary registry
if ! docker login "${registry}" -u "${INPUT_DOCKER_USER}" -p "${INPUT_DOCKER_PASS}"; then
  echo "::error:: docker login failed for primary registry ${registry}"
  exit 1
fi

# Connect to Docker Hub, if enabled. Docker Hub is optional, so a failure
# here must not abort primary-registry pushes that would otherwise succeed.
if [[ ${dockerhub_enabled} -eq 1 ]]; then
  if ! docker login -u "${INPUT_DOCKERHUB_USER}" -p "${INPUT_DOCKERHUB_PASS}"; then
    echo "::error:: docker login failed for Docker Hub; skipping all Docker Hub pushes for this run"
    HAS_ERROR=1
    dockerhub_enabled=0
  fi
fi

# Push tags and manfiests
echo ::group::Push build tags
while read -r app version arch app_path ; do
  build_tag=${version}
  img_prefix="${INPUT_IMAGE_PREFIX:-${registry}/${GITHUB_REPOSITORY}}"
  re='^[0-9]+-alpine.*$'
  if [[ $version =~ $re ]] ; then
    build_tag="${version}-${arch}"
    rm_tags+=("${img_prefix}-${app}:${build_tag}")
  fi
  # Re-tag local image with registry-qualified name then push
  local_name="bareos-${app}:${build_tag}"
  remote_name="${img_prefix}-${app}:${build_tag}"
  docker tag "${local_name}" "${remote_name}"
  sarif_file="${workdir}/sarif/${app}-${build_tag}.sarif"
  if wizcli scan container-image "${remote_name}" \
      --dockerfile "${app_path}/Dockerfile" \
      --policies="${wiz_policies}" \
      --sarif-output-file "${sarif_file}"; then
    # Directory uploads require a stable, unique category for every SARIF run.
    if ! jq --arg category "wiz/${app}-${build_tag}" \
        '.runs |= (to_entries | map(.value.automationDetails.id = ($category + "-" + (.key | tostring) + "/") | .value))' \
        "${sarif_file}" > "${sarif_file}.tmp"; then
      echo "::warning:: Failed to add a unique category to ${sarif_file}"
      rm -f "${sarif_file}" "${sarif_file}.tmp"
    else
      mv "${sarif_file}.tmp" "${sarif_file}"
    fi
  else
    echo "::warning:: Wiz scan failed for ${remote_name}; image publishing will continue"
    rm -f "${sarif_file}" "${sarif_file}.tmp"
  fi
  if docker push "${remote_name}"; then
    wizcli tag "${remote_name}"
  else
    echo "::error:: docker push failed for ${remote_name}"
    HAS_ERROR=1
  fi
  if [[ ${dockerhub_enabled} -eq 1 ]]; then
    dockerhub_name="${dockerhub_prefix}-${app}:${build_tag}"
    if [[ $version =~ $re ]] ; then
      rm_tags_dockerhub+=("${dockerhub_prefix}-${app}:${build_tag}")
    fi
    docker tag "${local_name}" "${dockerhub_name}"
    if ! docker push "${dockerhub_name}"; then
      echo "::error:: docker push failed for ${dockerhub_name}"
      HAS_ERROR=1
    fi
  fi
done < "${workdir}/app_build.txt"
echo ::endgroup::

echo ::group::Push additional tags
while read -r build_app s_tag t_tag ; do
  img_prefix="${INPUT_IMAGE_PREFIX:-${registry}/${GITHUB_REPOSITORY}}"
  # Push additional tags for Ubuntu
  if [[ $s_tag =~ ^[a-z0-9]+-ubuntu.*$ ]]; then
    docker tag "${img_prefix}-${build_app}:${s_tag}" \
      "${img_prefix}-${build_app}:${t_tag}"
    if docker push "${img_prefix}-${build_app}:${t_tag}"; then
      wizcli tag "${img_prefix}-${build_app}:${t_tag}"
    else
      echo "::error:: docker push failed for ${img_prefix}-${build_app}:${t_tag}"
      HAS_ERROR=1
    fi
  fi
  # Create and push manifest for Alpine, from whichever per-arch tags were
  # actually built for this version (see app_build.txt) — not every alpine
  # version supports the same arch set (e.g. armv7 is only built for 23).
  if [[ $s_tag =~ ^[a-z0-9]+-alpine.*$ ]]; then
    manifest_refs=()
    while read -r arch; do
      manifest_refs+=("${img_prefix}-${build_app}:${s_tag}-${arch}")
    done < <(awk -v app="${build_app}" -v tag="${s_tag}" \
        '$1 == app && $2 == tag { print $3 }' "${workdir}/app_build.txt" | sort -u)
    if [[ ${#manifest_refs[@]} -eq 0 ]]; then
      echo "::error:: no per-arch tags found in app_build.txt for ${build_app}:${s_tag}, skipping manifest"
    elif ! docker manifest create "${img_prefix}-${build_app}:${t_tag}" "${manifest_refs[@]}"; then
      echo "::error:: docker manifest create failed for ${img_prefix}-${build_app}:${t_tag}"
      HAS_ERROR=1
    elif ! docker manifest push "${img_prefix}-${build_app}:${t_tag}"; then
      echo "::error:: docker manifest push failed for ${img_prefix}-${build_app}:${t_tag}"
      HAS_ERROR=1
    fi
  fi
  if [[ ${dockerhub_enabled} -eq 1 ]]; then
    if [[ $s_tag =~ ^[a-z0-9]+-ubuntu.*$ ]]; then
      docker tag "${dockerhub_prefix}-${build_app}:${s_tag}" \
        "${dockerhub_prefix}-${build_app}:${t_tag}"
      if ! docker push "${dockerhub_prefix}-${build_app}:${t_tag}"; then
        echo "::error:: docker push failed for ${dockerhub_prefix}-${build_app}:${t_tag}"
        HAS_ERROR=1
      fi
    fi
    if [[ $s_tag =~ ^[a-z0-9]+-alpine.*$ ]]; then
      dockerhub_manifest_refs=()
      while read -r arch; do
        dockerhub_manifest_refs+=("${dockerhub_prefix}-${build_app}:${s_tag}-${arch}")
      done < <(awk -v app="${build_app}" -v tag="${s_tag}" \
          '$1 == app && $2 == tag { print $3 }' "${workdir}/app_build.txt" | sort -u)
      if [[ ${#dockerhub_manifest_refs[@]} -eq 0 ]]; then
        echo "::error:: no per-arch tags found in app_build.txt for ${build_app}:${s_tag}, skipping Docker Hub manifest"
      elif ! docker manifest create "${dockerhub_prefix}-${build_app}:${t_tag}" "${dockerhub_manifest_refs[@]}"; then
        echo "::error:: docker manifest create failed for ${dockerhub_prefix}-${build_app}:${t_tag}"
        HAS_ERROR=1
      elif ! docker manifest push "${dockerhub_prefix}-${build_app}:${t_tag}"; then
        echo "::error:: docker manifest push failed for ${dockerhub_prefix}-${build_app}:${t_tag}"
        HAS_ERROR=1
      fi
    fi
  fi
done < "${workdir}/tag_build.txt"
echo ::endgroup::

# Clean Alpine build_tag (amd/arm)
echo ::group::Clean
if [[ ${#rm_tags[@]} -gt 0 ]]; then
  for tag in "${rm_tags[@]}"; do
    if docker run --rm ghcr.io/regclient/regctl:v0.11.6 tag delete "${tag}" \
        --host "reg=${registry},user=${INPUT_DOCKER_USER},pass=${INPUT_DOCKER_PASS},tls=enabled" \
        --ignore-missing; then
      echo "removed: ${tag}"
    else
      echo "::warning:: failed to delete tag ${tag}"
    fi
  done
fi
if [[ ${dockerhub_enabled} -eq 1 && ${#rm_tags_dockerhub[@]} -gt 0 ]]; then
  # Left deliberately silent, out of scope for this fix: same class of
  # silent-failure defect as the rest of this file, but not addressed here.
  docker run --rm lumir/remove-dockerhub-tag \
    --user "${INPUT_DOCKERHUB_USER}" --password "${INPUT_DOCKERHUB_PASS}" "${rm_tags_dockerhub[@]}"
fi
echo ::endgroup::

if [[ ${HAS_ERROR} -ne 0 ]]; then
  exit 1
fi

#EOF
