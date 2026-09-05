#!/usr/bin/env bash
# Stub-harness regression test for push-bareos-app/entrypoint.sh.
#
# Fakes `docker`, `wizcli` and `jq` on PATH so this runs with no network and
# no real registry/Docker Hub credentials. Each scenario builds a fresh
# fixture workspace (app_build.txt / tag_build.txt + dummy tar/Dockerfiles),
# runs the real entrypoint.sh against it, and inspects both the exit code
# and a call-log of every docker/wizcli invocation. The thing under test is
# the HAS_ERROR control flow: a real push/manifest/login failure must (a)
# make the script exit nonzero and (b) never stop it from attempting every
# remaining row.
#
# Not wired into CI (test-n-lint.yml) as part of this change — that's a
# separate follow-up decision. Run manually:
#   bash .github/actions/push-bareos-app/test/entrypoint_test.sh
#
# Known limitation: the fake `docker manifest create` can't reproduce the
# real failure mode where a manifest list of that name already exists
# locally without --amend. Not a gap in the entrypoint.sh fix (each tag is
# only created once per real job run) — just a limit of what this stub
# checks.

set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENTRYPOINT="${SCRIPT_DIR}/../entrypoint.sh"

FAILURES=0
declare -a WORKDIRS=()

cleanup_all() {
  local d
  for d in "${WORKDIRS[@]}"; do
    rm -rf "${d}"
  done
}
trap cleanup_all EXIT

fail() {
  echo "FAIL: $1"
  FAILURES=$((FAILURES + 1))
}

assert_eq() {
  local actual="$1" expected="$2" msg="$3"
  if [[ "${actual}" != "${expected}" ]]; then
    fail "${msg}: expected '${expected}', got '${actual}'"
  fi
}

assert_line() {
  local pattern="$1"
  grep -qE "^${pattern}\$" "${CALL_LOG}" || fail "expected call not found: ${pattern}"
}

assert_no_line() {
  local pattern="$1"
  if grep -qE "^${pattern}\$" "${CALL_LOG}"; then
    fail "unexpected call found: ${pattern}"
  fi
}

assert_count() {
  local pattern="$1" expected="$2" actual
  actual=$(grep -cE "^${pattern}" "${CALL_LOG}")
  if [[ "${actual}" -ne "${expected}" ]]; then
    fail "expected ${expected} call(s) matching '${pattern}', got ${actual}"
  fi
}

setup_fixture() {
  WORKDIR="$(mktemp -d)"
  WORKDIRS+=("${WORKDIR}")
  BIN_DIR="${WORKDIR}/bin"
  GITHUB_WORKSPACE="${WORKDIR}/workspace"
  CALL_LOG="${WORKDIR}/calls.log"
  : > "${CALL_LOG}"

  mkdir -p "${BIN_DIR}" "${GITHUB_WORKSPACE}/build"
  mkdir -p "${GITHUB_WORKSPACE}/director-pgsql/24-ubuntu" \
           "${GITHUB_WORKSPACE}/director-pgsql/24-alpine"
  : > "${GITHUB_WORKSPACE}/director-pgsql/24-ubuntu/Dockerfile"
  : > "${GITHUB_WORKSPACE}/director-pgsql/24-alpine/Dockerfile"
  : > "${GITHUB_WORKSPACE}/build/bareos-director-pgsql.tar"

  # One ubuntu row, one alpine row built for two arches.
  cat > "${GITHUB_WORKSPACE}/build/app_build.txt" <<'FIXTURE'
director-pgsql 24-ubuntu amd64 director-pgsql/24-ubuntu
director-pgsql 24-alpine amd64 director-pgsql/24-alpine
director-pgsql 24-alpine arm64 director-pgsql/24-alpine
FIXTURE

  cat > "${GITHUB_WORKSPACE}/build/tag_build.txt" <<'FIXTURE'
director-pgsql 24-ubuntu 24
director-pgsql 24-alpine 24-alpine
FIXTURE

  cat > "${BIN_DIR}/docker" <<'FAKE'
#!/usr/bin/env bash
echo "docker $*" >> "${CALL_LOG}"
cmd="$1"
case "${cmd}" in
  login)
    shift
    if [[ "${1:-}" != -* ]]; then
      # docker login <registry> -u ... -p ...  (primary registry)
      [[ "${FAIL_PRIMARY_LOGIN:-0}" -eq 1 ]] && exit 1
    else
      # docker login -u ... -p ...  (Docker Hub, no positional registry)
      [[ "${FAIL_DOCKERHUB_LOGIN:-0}" -eq 1 ]] && exit 1
    fi
    exit 0
    ;;
  push)
    ref="$2"
    if [[ -n "${FAIL_PUSH_MATCH:-}" && "${ref}" == *"${FAIL_PUSH_MATCH}"* ]]; then
      exit 1
    fi
    exit 0
    ;;
  manifest)
    ref="$3"
    if [[ -n "${FAIL_MANIFEST_MATCH:-}" && "${ref}" == *"${FAIL_MANIFEST_MATCH}"* ]]; then
      exit 1
    fi
    exit 0
    ;;
  *)
    exit 0
    ;;
esac
FAKE
  chmod +x "${BIN_DIR}/docker"

  cat > "${BIN_DIR}/wizcli" <<'FAKE'
#!/usr/bin/env bash
echo "wizcli $*" >> "${CALL_LOG}"
if [[ "${1:-}" == "scan" ]]; then
  prev=""
  for arg in "$@"; do
    if [[ "${prev}" == "--sarif-output-file" ]]; then
      echo '{"runs":[]}' > "${arg}"
    fi
    prev="${arg}"
  done
fi
exit 0
FAKE
  chmod +x "${BIN_DIR}/wizcli"

  cat > "${BIN_DIR}/jq" <<'FAKE'
#!/usr/bin/env bash
echo "jq $*" >> "${CALL_LOG}"
last="${@: -1}"
cat "${last}"
FAKE
  chmod +x "${BIN_DIR}/jq"
}

reset_env() {
  unset INPUT_DOCKERHUB_USER INPUT_DOCKERHUB_PASS
  unset FAIL_PRIMARY_LOGIN FAIL_DOCKERHUB_LOGIN FAIL_PUSH_MATCH FAIL_MANIFEST_MATCH
}

base_env() {
  export GITHUB_WORKSPACE CALL_LOG
  export GITHUB_REPOSITORY="bareos-owner/bareos"
  export INPUT_DOCKER_USER="user"
  export INPUT_DOCKER_PASS="pass"
  export INPUT_REGISTRY="registry.example.com"
  export INPUT_IMAGE_PREFIX="test-registry/bareos"
  export INPUT_WIZ_CLIENT_ID="wid"
  export INPUT_WIZ_CLIENT_SECRET="wsecret"
}

run_entrypoint() {
  (
    cd "${GITHUB_WORKSPACE}" || exit 99
    export PATH="${BIN_DIR}:${PATH}"
    bash "${ENTRYPOINT}"
  ) > "${WORKDIR}/output.log" 2>&1
  return $?
}

scenario_all_success() {
  echo "--- scenario (a): all success ---"
  setup_fixture
  reset_env
  base_env
  export INPUT_DOCKERHUB_USER="dhuser"
  export INPUT_DOCKERHUB_PASS="dhpass"

  run_entrypoint
  local rc=$?

  assert_eq "${rc}" "0" "exit code"
  assert_count "^docker push " 8
  assert_count "^docker manifest create " 2
  assert_count "^docker manifest push " 2
  assert_line "docker push test-registry/bareos-director-pgsql:24-ubuntu"
  assert_line "docker push test-registry/bareos-director-pgsql:24-alpine-amd64"
  assert_line "docker push test-registry/bareos-director-pgsql:24-alpine-arm64"
  assert_line "docker push darkvex/bareos-director-pgsql:24-ubuntu"
  assert_line "docker push darkvex/bareos-director-pgsql:24-alpine-amd64"
  assert_line "docker push darkvex/bareos-director-pgsql:24-alpine-arm64"
  assert_line "docker push test-registry/bareos-director-pgsql:24"
  assert_line "docker push darkvex/bareos-director-pgsql:24"
  assert_line "docker manifest create test-registry/bareos-director-pgsql:24-alpine test-registry/bareos-director-pgsql:24-alpine-amd64 test-registry/bareos-director-pgsql:24-alpine-arm64"
  assert_line "docker manifest push test-registry/bareos-director-pgsql:24-alpine"
  assert_line "docker manifest create darkvex/bareos-director-pgsql:24-alpine darkvex/bareos-director-pgsql:24-alpine-amd64 darkvex/bareos-director-pgsql:24-alpine-arm64"
  assert_line "docker manifest push darkvex/bareos-director-pgsql:24-alpine"
}

scenario_single_failed_push() {
  echo "--- scenario (b): single failed push ---"
  setup_fixture
  reset_env
  base_env
  export FAIL_PUSH_MATCH="24-alpine-amd64"

  run_entrypoint
  local rc=$?

  assert_eq "${rc}" "1" "exit code"
  # The failing row's push must still have been attempted...
  assert_line "docker push test-registry/bareos-director-pgsql:24-alpine-amd64"
  # ...and every other row's push/manifest calls must still happen.
  assert_line "docker push test-registry/bareos-director-pgsql:24-ubuntu"
  assert_line "docker push test-registry/bareos-director-pgsql:24-alpine-arm64"
  assert_line "docker push test-registry/bareos-director-pgsql:24"
  assert_line "docker manifest create test-registry/bareos-director-pgsql:24-alpine test-registry/bareos-director-pgsql:24-alpine-amd64 test-registry/bareos-director-pgsql:24-alpine-arm64"
  assert_line "docker manifest push test-registry/bareos-director-pgsql:24-alpine"
}

scenario_failed_manifest_create() {
  echo "--- scenario (c): failed manifest create ---"
  setup_fixture
  reset_env
  base_env
  export FAIL_MANIFEST_MATCH="test-registry/bareos-director-pgsql:24-alpine"

  run_entrypoint
  local rc=$?

  assert_eq "${rc}" "1" "exit code"
  assert_line "docker manifest create test-registry/bareos-director-pgsql:24-alpine test-registry/bareos-director-pgsql:24-alpine-amd64 test-registry/bareos-director-pgsql:24-alpine-arm64"
  # The elif must short-circuit: no push attempt for a manifest that was
  # never created.
  assert_no_line "docker manifest push test-registry/bareos-director-pgsql:24-alpine"
  # Unrelated rows still proceed.
  assert_line "docker push test-registry/bareos-director-pgsql:24-ubuntu"
}

scenario_primary_login_failure() {
  echo "--- scenario (d): primary registry login failure ---"
  setup_fixture
  reset_env
  base_env
  export FAIL_PRIMARY_LOGIN=1

  run_entrypoint
  local rc=$?

  assert_eq "${rc}" "1" "exit code"
  if grep -qE "^docker (push|manifest)" "${CALL_LOG}"; then
    fail "push/manifest call attempted after primary registry login failure"
  fi
}

scenario_dockerhub_login_failure() {
  echo "--- scenario (e): Docker Hub-only login failure ---"
  setup_fixture
  reset_env
  base_env
  export INPUT_DOCKERHUB_USER="dhuser"
  export INPUT_DOCKERHUB_PASS="dhpass"
  export FAIL_DOCKERHUB_LOGIN=1

  run_entrypoint
  local rc=$?

  # Fails only at the very end via HAS_ERROR, not immediately.
  assert_eq "${rc}" "1" "exit code"
  assert_line "docker login -u dhuser -p dhpass"
  # Primary-registry work must proceed as if Docker Hub were never enabled.
  assert_line "docker push test-registry/bareos-director-pgsql:24-ubuntu"
  assert_line "docker push test-registry/bareos-director-pgsql:24-alpine-amd64"
  assert_line "docker push test-registry/bareos-director-pgsql:24-alpine-arm64"
  assert_line "docker push test-registry/bareos-director-pgsql:24"
  assert_line "docker manifest create test-registry/bareos-director-pgsql:24-alpine test-registry/bareos-director-pgsql:24-alpine-amd64 test-registry/bareos-director-pgsql:24-alpine-arm64"
  assert_line "docker manifest push test-registry/bareos-director-pgsql:24-alpine"
  if grep -qE "^docker (push|manifest create|manifest push) darkvex/bareos" "${CALL_LOG}"; then
    fail "Docker Hub push/manifest call attempted after Docker Hub login failure"
  fi
}

scenario_all_success
scenario_single_failed_push
scenario_failed_manifest_create
scenario_primary_login_failure
scenario_dockerhub_login_failure

if [[ "${FAILURES}" -eq 0 ]]; then
  echo "All scenarios passed."
  exit 0
else
  echo "${FAILURES} assertion(s) failed."
  exit 1
fi
