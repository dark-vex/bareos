#!/usr/bin/env bash

workdir="${GITHUB_WORKSPACE}/build"
docker_files=$(find "${workdir}/" -name "bareos-*.tar" 2>/dev/null)
rm_tags=()

mkdir -p "${workdir}/sarif"

# Enable experimental feature in Docker
export DOCKER_CLI_EXPERIMENTAL="enabled"

# wizcli reads these automatically for scan/tag; no separate auth step needed
export WIZ_CLIENT_ID="${INPUT_WIZ_CLIENT_ID}"
export WIZ_CLIENT_SECRET="${INPUT_WIZ_CLIENT_SECRET}"

# TEMPORARY DIAGNOSTIC (remove once Wiz connectivity/auth is confirmed working):
# confirms the secrets actually made it into the container without ever
# printing their value.
echo ::group::Wiz credential diagnostic
echo "WIZ_CLIENT_ID length: ${#WIZ_CLIENT_ID}"
echo "WIZ_CLIENT_SECRET length: ${#WIZ_CLIENT_SECRET}"
echo ::endgroup::

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
  sarif_file="${workdir}/sarif/${app}-${build_tag}.json"
  wiz_log_file="${workdir}/sarif/${app}-${build_tag}.wizlog"
  if wizcli scan container-image "${remote_name}" \
      --dockerfile "${app_path}/Dockerfile" \
      --sarif-output-file "${sarif_file}" \
      --log "${wiz_log_file}"; then
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
  # TEMPORARY DIAGNOSTIC (remove once Wiz connectivity/auth is confirmed working)
  if [[ -s "${wiz_log_file}" ]]; then
    echo "::group::Wiz debug log for ${remote_name}"
    cat "${wiz_log_file}"
    echo "::endgroup::"
  fi
  if docker push "${remote_name}"; then
    wizcli tag "${remote_name}"
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
    else
      docker manifest create "${img_prefix}-${build_app}:${t_tag}" "${manifest_refs[@]}"
      if docker manifest push "${img_prefix}-${build_app}:${t_tag}"; then
        wizcli tag "${img_prefix}-${build_app}:${t_tag}"
      fi
    fi
  fi
done < "${workdir}/tag_build.txt"
echo ::endgroup::

# Clean Alpine build_tag (amd/arm)
echo ::group::Clean
if [[ ${#rm_tags[@]} -gt 0 ]]; then
  docker run --rm lumir/remove-dockerhub-tag \
    --user "${GITHUB_ACTOR}" --password "${INPUT_DOCKER_PASS}" "${rm_tags[@]}"
fi
echo ::endgroup::

#EOF
