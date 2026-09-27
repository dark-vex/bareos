#!/usr/bin/env bash

workdir="${GITHUB_WORKSPACE}/build"
docker_files=$(find "${workdir}/" -name "bareos-*.tar" 2>/dev/null)
rm_tags=()
rm_tags_dockerhub=()
declare -A blocked_build_tags

mkdir -p "${workdir}/sarif"

digest_file="${workdir}/pushed_digests.txt"
: > "${digest_file}"

strip_tag() {
  local ref="$1" tag
  tag="${ref##*:}"
  if [[ "${tag}" == */* ]]; then
    printf '%s\n' "${ref}"
  else
    printf '%s\n' "${ref%:*}"
  fi
}

record_digest() {
  local ref="$1" output="$2" digest name
  digest=$(printf '%s' "${output}" | grep -oE 'sha256:[0-9a-f]{64}' | tail -1)
  if [[ -n "${digest}" ]]; then
    name=$(strip_tag "${ref}")
    echo "${name}@${digest}" >> "${digest_file}"
  fi
}

# Enable experimental feature in Docker
export DOCKER_CLI_EXPERIMENTAL="enabled"

# wizcli reads these automatically for scan/tag; no separate auth step needed
export WIZ_CLIENT_ID="${INPUT_WIZ_CLIENT_ID}"
export WIZ_CLIENT_SECRET="${INPUT_WIZ_CLIENT_SECRET}"

# Fixed set of Wiz policies enforced on every container-image scan
wiz_policies='[ddl] Default secrets policy,[ddl] Default sensitive data policy,[ddl] Default software license policy,[ddl] Default vulnerabilities policy'

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
if ! printf '%s' "${INPUT_DOCKER_PASS}" | docker login "${registry}" -u "${INPUT_DOCKER_USER}" --password-stdin; then
  echo "::error:: docker login failed for primary registry ${registry}"
  exit 1
fi

# Connect to Docker Hub, if enabled. Docker Hub is optional, so a failure
# here must not abort primary-registry pushes that would otherwise succeed.
if [[ ${dockerhub_enabled} -eq 1 ]]; then
  if ! printf '%s' "${INPUT_DOCKERHUB_PASS}" | docker login -u "${INPUT_DOCKERHUB_USER}" --password-stdin; then
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
  fi
  # Re-tag local image with registry-qualified name then push
  local_name="bareos-${app}:${build_tag}"
  remote_name="${img_prefix}-${app}:${build_tag}"
  docker tag "${local_name}" "${remote_name}"
  sarif_file="${workdir}/sarif/${app}-${build_tag}.sarif"
  wiz_scan_ok=1
  if ! wizcli scan container-image "${remote_name}" \
      --dockerfile "${app_path}/Dockerfile" \
      --policies="${wiz_policies}" \
      --sarif-output-file "${sarif_file}"; then
    wiz_scan_ok=0
  fi
  if [[ -s "${sarif_file}" ]]; then
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
    rm -f "${sarif_file}" "${sarif_file}.tmp"
  fi
  if [[ ${wiz_scan_ok} -eq 0 ]]; then
    echo "::error:: Wiz scan failed for ${remote_name}; not publishing"
    HAS_ERROR=1
    blocked_build_tags["${app}|${build_tag}"]=1
  else
    if [[ $version =~ $re ]] ; then
      rm_tags+=("${img_prefix}-${app}:${build_tag}")
    fi
    push_output=$(docker push "${remote_name}" 2>&1)
    push_rc=$?
    printf '%s\n' "${push_output}"
    if [[ ${push_rc} -eq 0 ]]; then
      wizcli tag "${remote_name}"
      record_digest "${remote_name}" "${push_output}"
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
      dockerhub_push_output=$(docker push "${dockerhub_name}" 2>&1)
      dockerhub_push_rc=$?
      printf '%s\n' "${dockerhub_push_output}"
      if [[ ${dockerhub_push_rc} -eq 0 ]]; then
        record_digest "${dockerhub_name}" "${dockerhub_push_output}"
      else
        echo "::error:: docker push failed for ${dockerhub_name}"
        HAS_ERROR=1
      fi
    fi
  fi
done < "${workdir}/app_build.txt"
echo ::endgroup::

echo ::group::Push additional tags
while read -r build_app s_tag t_tag ; do
  img_prefix="${INPUT_IMAGE_PREFIX:-${registry}/${GITHUB_REPOSITORY}}"
  # Push additional tags for Ubuntu
  if [[ $s_tag =~ ^[a-z0-9]+-ubuntu.*$ ]]; then
    if [[ -n "${blocked_build_tags["${build_app}|${s_tag}"]:-}" ]]; then
      echo "::warning:: skipping ${img_prefix}-${build_app}:${t_tag}, source ${build_app}:${s_tag} was blocked by Wiz scan"
    else
      docker tag "${img_prefix}-${build_app}:${s_tag}" \
        "${img_prefix}-${build_app}:${t_tag}"
      tag_push_output=$(docker push "${img_prefix}-${build_app}:${t_tag}" 2>&1)
      tag_push_rc=$?
      printf '%s\n' "${tag_push_output}"
      if [[ ${tag_push_rc} -eq 0 ]]; then
        wizcli tag "${img_prefix}-${build_app}:${t_tag}"
        record_digest "${img_prefix}-${build_app}:${t_tag}" "${tag_push_output}"
      else
        echo "::error:: docker push failed for ${img_prefix}-${build_app}:${t_tag}"
        HAS_ERROR=1
      fi
    fi
  fi
  # Create and push manifest for Alpine, from whichever per-arch tags were
  # actually built for this version (see app_build.txt) — not every alpine
  # version supports the same arch set (e.g. armv7 is only built for 23).
  if [[ $s_tag =~ ^[a-z0-9]+-alpine.*$ ]]; then
    manifest_refs=()
    while read -r arch; do
      if [[ -z "${blocked_build_tags["${build_app}|${s_tag}-${arch}"]:-}" ]]; then
        manifest_refs+=("${img_prefix}-${build_app}:${s_tag}-${arch}")
      fi
    done < <(awk -v app="${build_app}" -v tag="${s_tag}" \
        '$1 == app && $2 == tag { print $3 }' "${workdir}/app_build.txt" | sort -u)
    if [[ ${#manifest_refs[@]} -eq 0 ]]; then
      echo "::error:: no per-arch tags found in app_build.txt for ${build_app}:${s_tag}, skipping manifest"
    elif ! docker manifest create "${img_prefix}-${build_app}:${t_tag}" "${manifest_refs[@]}"; then
      echo "::error:: docker manifest create failed for ${img_prefix}-${build_app}:${t_tag}"
      HAS_ERROR=1
    else
      manifest_push_output=$(docker manifest push "${img_prefix}-${build_app}:${t_tag}" 2>&1)
      manifest_push_rc=$?
      printf '%s\n' "${manifest_push_output}"
      if [[ ${manifest_push_rc} -eq 0 ]]; then
        record_digest "${img_prefix}-${build_app}:${t_tag}" "${manifest_push_output}"
      else
        echo "::error:: docker manifest push failed for ${img_prefix}-${build_app}:${t_tag}"
        HAS_ERROR=1
      fi
    fi
  fi
  if [[ ${dockerhub_enabled} -eq 1 ]]; then
    if [[ $s_tag =~ ^[a-z0-9]+-ubuntu.*$ ]]; then
      if [[ -z "${blocked_build_tags["${build_app}|${s_tag}"]:-}" ]]; then
        docker tag "${dockerhub_prefix}-${build_app}:${s_tag}" \
          "${dockerhub_prefix}-${build_app}:${t_tag}"
        dockerhub_tag_push_output=$(docker push "${dockerhub_prefix}-${build_app}:${t_tag}" 2>&1)
        dockerhub_tag_push_rc=$?
        printf '%s\n' "${dockerhub_tag_push_output}"
        if [[ ${dockerhub_tag_push_rc} -eq 0 ]]; then
          record_digest "${dockerhub_prefix}-${build_app}:${t_tag}" "${dockerhub_tag_push_output}"
        else
          echo "::error:: docker push failed for ${dockerhub_prefix}-${build_app}:${t_tag}"
          HAS_ERROR=1
        fi
      fi
    fi
    if [[ $s_tag =~ ^[a-z0-9]+-alpine.*$ ]]; then
      dockerhub_manifest_refs=()
      while read -r arch; do
        if [[ -z "${blocked_build_tags["${build_app}|${s_tag}-${arch}"]:-}" ]]; then
          dockerhub_manifest_refs+=("${dockerhub_prefix}-${build_app}:${s_tag}-${arch}")
        fi
      done < <(awk -v app="${build_app}" -v tag="${s_tag}" \
          '$1 == app && $2 == tag { print $3 }' "${workdir}/app_build.txt" | sort -u)
      if [[ ${#dockerhub_manifest_refs[@]} -eq 0 ]]; then
        echo "::error:: no per-arch tags found in app_build.txt for ${build_app}:${s_tag}, skipping Docker Hub manifest"
      elif ! docker manifest create "${dockerhub_prefix}-${build_app}:${t_tag}" "${dockerhub_manifest_refs[@]}"; then
        echo "::error:: docker manifest create failed for ${dockerhub_prefix}-${build_app}:${t_tag}"
        HAS_ERROR=1
      else
        dockerhub_manifest_push_output=$(docker manifest push "${dockerhub_prefix}-${build_app}:${t_tag}" 2>&1)
        dockerhub_manifest_push_rc=$?
        printf '%s\n' "${dockerhub_manifest_push_output}"
        if [[ ${dockerhub_manifest_push_rc} -eq 0 ]]; then
          record_digest "${dockerhub_prefix}-${build_app}:${t_tag}" "${dockerhub_manifest_push_output}"
        else
          echo "::error:: docker manifest push failed for ${dockerhub_prefix}-${build_app}:${t_tag}"
          HAS_ERROR=1
        fi
      fi
    fi
  fi
done < "${workdir}/tag_build.txt"
echo ::endgroup::

# Clean Alpine build_tag (amd/arm)
echo ::group::Clean
if [[ ${#rm_tags[@]} -gt 0 ]]; then
  for tag in "${rm_tags[@]}"; do
    if regctl tag delete "${tag}" \
        --host "reg=${registry},tls=enabled" \
        --ignore-missing; then
      echo "removed: ${tag}"
    else
      echo "::warning:: failed to delete tag ${tag}"
    fi
  done
fi
if [[ ${dockerhub_enabled} -eq 1 && ${#rm_tags_dockerhub[@]} -gt 0 ]]; then
  dockerhub_login_response_file=$(mktemp)
  chmod 600 "${dockerhub_login_response_file}"
  if ! (set -o pipefail
        jq -n '{identifier: env.INPUT_DOCKERHUB_USER, secret: env.INPUT_DOCKERHUB_PASS}' \
          | curl --fail -sS -H 'Content-Type: application/json' --data-binary @- \
              https://hub.docker.com/v2/auth/token) > "${dockerhub_login_response_file}"; then
    echo "::warning:: failed to authenticate to Docker Hub API for tag deletion"
    rm -f "${dockerhub_login_response_file}"
  else
    dockerhub_token=$(jq -r '.access_token' < "${dockerhub_login_response_file}")
    rm -f "${dockerhub_login_response_file}"
    if [[ -z "${dockerhub_token}" || "${dockerhub_token}" == "null" ]]; then
      echo "::warning:: failed to authenticate to Docker Hub API for tag deletion"
    else
      dockerhub_auth_header_file=$(mktemp)
      chmod 600 "${dockerhub_auth_header_file}"
      printf 'Authorization: Bearer %s\n' "${dockerhub_token}" > "${dockerhub_auth_header_file}"
      for tag in "${rm_tags_dockerhub[@]}"; do
        ns_repo="${tag%%:*}"
        dh_tag_name="${tag##*:}"
        dh_namespace="${ns_repo%%/*}"
        dh_repo="${ns_repo#*/}"
        dockerhub_delete_status=$(curl -sS -o /dev/null -w '%{http_code}' -X DELETE \
          -H @"${dockerhub_auth_header_file}" \
          "https://hub.docker.com/v2/repositories/${dh_namespace}/${dh_repo}/tags/${dh_tag_name}/")
        if [[ "${dockerhub_delete_status}" =~ ^(200|202|204|404)$ ]]; then
          echo "removed: ${tag}"
        else
          echo "::warning:: failed to delete Docker Hub tag ${tag}"
        fi
      done
      rm -f "${dockerhub_auth_header_file}"
    fi
  fi
fi
echo ::endgroup::

if [[ -n "${GITHUB_OUTPUT:-}" ]]; then
  echo "pushed_digests_file=build/pushed_digests.txt" >> "${GITHUB_OUTPUT}"
fi

if [[ ${HAS_ERROR} -ne 0 ]]; then
  exit 1
fi

#EOF
