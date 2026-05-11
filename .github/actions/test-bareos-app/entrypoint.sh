#!/usr/bin/env bash

workdir="${GITHUB_WORKSPACE}/build"
docker_files=$(find "${workdir}/" -name "bareos-*.tar" 2>/dev/null)

# Load Dockerfiles
echo ::group::Load Dockerfile
echo "${docker_files}"
for file in $docker_files ; do
  docker load --input "$file"
done
docker images
echo ::endgroup::

# Test images
echo ::group::Test build tags
HAS_ERROR=0
while read app version arch path ; do
  # If nightly image, don't test
  re_nightly='^nightly-.*$'
  [[ ${version} =~ $re_nightly ]] && continue

  ARGS=''
  CMD=()
  build_tag=${version}
  re_alpine='^[0-9]+-alpine.*$'
  re_ubuntu='^[0-9]+-ubuntu.*$'

  # Define args and command
  if [[ $version =~ $re_alpine ]] ; then
    build_tag="${version}-${arch}"

    if [[ "$app" == "api" ]] ; then
      # Run through sh -c so the pipe executes inside the container
      CMD=(sh -c "python -m pip show bareos-restapi | awk '/^Version:/ {print \$2}'")
    elif [[ "$app" == "webui" ]] ; then
      CMD=(apk list --installed bareos-webui)
    else
      CMD=(apk list --installed bareos)
    fi
  fi

  if [[ $version =~ $re_ubuntu ]] ; then
    CMD=(dpkg-query --showformat='${Version}' --show "bareos-${app}")
  fi

  if [[ "$app" == "director" ]] ; then
    ARGS="-e CI_TEST=true"
  fi

  # Check if Dockerfile exist
  if [[ ! -f ${workdir}/bareos-${app}-${build_tag}.tar ]] ; then
    echo ::error::"ERROR-test: $workdir/bareos-${app}-${build_tag}.tar not found"
    HAS_ERROR=1
    continue
  fi

  # Run docker and check version
  img_version=$(docker run -t --rm ${ARGS} \
    "${INPUT_REGISTRY}/${GITHUB_REPOSITORY}-${app}:${build_tag}" \
    "${CMD[@]}" | tail -1)

  if [[ $version =~ $re_alpine ]] ; then
    img_version=$(echo "$img_version" |sed -n 's#[a-z-]*\(.*\)#\1#p')
  fi

  short_img_version=$(echo "$img_version" |cut -d'.' -f1)
  short_version=$(echo "$version" |cut -d'-' -f1)

  # Guard: extraction must yield a number, otherwise the check below silently mis-passes
  if ! [[ $short_img_version =~ ^[0-9]+$ ]] ; then
    echo ::error::"ERROR-test: ${app}:${build_tag} returned non-numeric version '${img_version}'"
    exit 1
  fi

  if (( short_img_version != short_version )) ; then
    echo ::error::"ERROR-test: ${app}:${build_tag} is ${short_img_version}"
    HAS_ERROR=1
  else
    echo "OK: ${app}:${build_tag} is Bareos v${short_img_version}"
  fi

done < "${workdir}/app_build.txt"
echo ::endgroup::

if [[ $HAS_ERROR -ne 0 ]]; then
  exit 1
fi

#EOF
