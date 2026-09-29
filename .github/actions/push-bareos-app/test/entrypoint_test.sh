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

fake_digest_for() {
  printf '%s' "$1" | sha256sum | cut -d' ' -f1
}

assert_digest_line() {
  local name="$1" pushed_ref="$2" digest expected
  digest=$(fake_digest_for "${pushed_ref}")
  expected="${name}@sha256:${digest}"
  grep -qxF "${expected}" "${DIGEST_FILE}" || fail "expected digest line not found: ${expected}"
}

assert_no_digest_line_for() {
  local pushed_ref="$1" digest
  digest=$(fake_digest_for "${pushed_ref}")
  if grep -q "sha256:${digest}\$" "${DIGEST_FILE}"; then
    fail "unexpected digest line found for ${pushed_ref}"
  fi
}

assert_digest_line_count() {
  local expected="$1" actual
  actual=$(grep -c '.' "${DIGEST_FILE}")
  if [[ "${actual}" -ne "${expected}" ]]; then
    fail "expected ${expected} digest line(s), got ${actual}"
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
    cat >/dev/null
    if [[ "${1:-}" != -* ]]; then
      [[ "${FAIL_PRIMARY_LOGIN:-0}" -eq 1 ]] && exit 1
    else
      [[ "${FAIL_DOCKERHUB_LOGIN:-0}" -eq 1 ]] && exit 1
    fi
    exit 0
    ;;
  push)
    ref="$2"
    if [[ -n "${FAIL_PUSH_MATCH:-}" && "${ref}" == *"${FAIL_PUSH_MATCH}"* ]]; then
      exit 1
    fi
    fake_digest=$(printf '%s' "${ref}" | sha256sum | cut -d' ' -f1)
    echo "latest: digest: sha256:${fake_digest} size: 1234"
    exit 0
    ;;
  manifest)
    sub="$2"
    ref="$3"
    if [[ -n "${FAIL_MANIFEST_MATCH:-}" && "${ref}" == *"${FAIL_MANIFEST_MATCH}"* ]]; then
      exit 1
    fi
    if [[ "${sub}" == "push" ]]; then
      fake_digest=$(printf '%s' "${ref}" | sha256sum | cut -d' ' -f1)
      echo "sha256:${fake_digest}"
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
  image_ref="$3"
  prev=""
  for arg in "$@"; do
    if [[ "${prev}" == "--sarif-output-file" ]]; then
      echo '{"runs":[]}' > "${arg}"
    fi
    prev="${arg}"
  done
  if [[ -n "${FAIL_WIZ_SCAN:-}" && "${image_ref}" == *"${FAIL_WIZ_SCAN}"* ]]; then
    exit 1
  fi
fi
exit 0
FAKE
  chmod +x "${BIN_DIR}/wizcli"

  cat > "${BIN_DIR}/jq" <<'FAKE'
#!/usr/bin/env bash
echo "jq $*" >> "${CALL_LOG}"
if [[ "${1:-}" == "-n" ]]; then
  echo '{}'
  exit 0
fi
if [[ "$*" == *"access_token"* ]]; then
  cat >/dev/null
  echo "jwt"
  exit 0
fi
last="${@: -1}"
if [[ "${last}" == 'if type == "object" and has("results") then (.results | type) else "invalid" end' ]]; then
  input=$(cat)
  trimmed="$(printf '%s' "${input}" | tr -d '[:space:]')"
  if [[ "${trimmed}" == \{*\"results\":\[*\]* ]]; then
    echo "array"
  else
    echo "invalid"
  fi
  exit 0
fi
if [[ "${last}" == '.results[] | [.name, .digest] | @tsv' ]]; then
  input=$(cat)
  objs=$(printf '%s' "${input}" | grep -oE '\{[^{}]*\}')
  while IFS= read -r obj; do
    [[ -z "${obj}" ]] && continue
    name=$(printf '%s' "${obj}" | grep -oE '"name"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/.*"([^"]*)"$/\1/')
    digest=$(printf '%s' "${obj}" | grep -oE '"digest"[[:space:]]*:[[:space:]]*"[^"]*"' | sed -E 's/.*"([^"]*)"$/\1/')
    printf '%s\t%s\n' "${name}" "${digest}"
  done <<< "${objs}"
  exit 0
fi
if [[ "${last}" == '.next // empty' ]]; then
  input=$(cat)
  val=$(printf '%s\n' "${input}" | grep -oE '"next"[[:space:]]*:[[:space:]]*("[^"]*"|null)')
  val="${val#*:}"
  val="$(printf '%s' "${val}" | tr -d '[:space:]')"
  if [[ "${val}" == "null" || -z "${val}" ]]; then
    echo ""
  else
    val="${val#\"}"
    val="${val%\"}"
    echo "${val}"
  fi
  exit 0
fi
cat "${last}"
FAKE
  chmod +x "${BIN_DIR}/jq"

  cat > "${BIN_DIR}/curl" <<'FAKE'
#!/usr/bin/env bash
echo "curl $*" >> "${CALL_LOG}"
if [[ "$*" == *"@-"* ]]; then
  cat >/dev/null
fi
case "$*" in
  *"hub.docker.com/v2/auth/token"*)
    echo '{"token":"jwt","access_token":"jwt"}'
    exit 0
    ;;
  *"-X DELETE"*)
    echo "200"
    exit 0
    ;;
  *"/tags/?page_size=100"*)
    if [[ -n "${DOCKERHUB_MALFORMED_COUNT:-}" ]]; then
      counter_file="${DOCKERHUB_MALFORMED_COUNTER_FILE:-/tmp/dockerhub_malformed_counter}"
      count=0
      [[ -f "${counter_file}" ]] && count=$(cat "${counter_file}")
      if [[ "${count}" -lt "${DOCKERHUB_MALFORMED_COUNT}" ]]; then
        count=$((count + 1))
        echo "${count}" > "${counter_file}"
        echo 'null'
        exit 0
      fi
    fi
    if [[ "$*" == *"page=2"* && -n "${DOCKERHUB_TAGS_PAGE2_FILE:-}" ]]; then
      cat "${DOCKERHUB_TAGS_PAGE2_FILE}"
    elif [[ -n "${DOCKERHUB_TAGS_PAGE1_FILE:-}" ]]; then
      cat "${DOCKERHUB_TAGS_PAGE1_FILE}"
    else
      echo '{"results":[],"next":null}'
    fi
    exit 0
    ;;
esac
exit 0
FAKE
  chmod +x "${BIN_DIR}/curl"

  cat > "${BIN_DIR}/regctl" <<'FAKE'
#!/usr/bin/env bash
echo "regctl $*" >> "${CALL_LOG}"
if [[ "${1:-}" == "tag" && "${2:-}" == "ls" ]]; then
  repo="${3:-}"
  safe="${repo//\//_}"
  if [[ -n "${REGCTL_TAGS_DIR:-}" && -f "${REGCTL_TAGS_DIR}/${safe}.txt" ]]; then
    cat "${REGCTL_TAGS_DIR}/${safe}.txt"
  fi
  exit 0
fi
if [[ "${1:-}" == "image" && "${2:-}" == "digest" ]]; then
  ref="${3:-}"
  if [[ -n "${REGCTL_DIGEST_FAIL_MATCH:-}" && "${ref}" == *"${REGCTL_DIGEST_FAIL_MATCH}"* ]]; then
    exit 1
  fi
  fake_digest=$(printf '%s' "${ref}" | sha256sum | cut -d' ' -f1)
  echo "sha256:${fake_digest}"
  exit 0
fi
exit 0
FAKE
  chmod +x "${BIN_DIR}/regctl"
}

reset_env() {
  unset INPUT_DOCKERHUB_USER INPUT_DOCKERHUB_PASS
  unset FAIL_PRIMARY_LOGIN FAIL_DOCKERHUB_LOGIN FAIL_PUSH_MATCH FAIL_MANIFEST_MATCH
  unset FAIL_WIZ_SCAN
  unset REGCTL_TAGS_DIR REGCTL_DIGEST_FAIL_MATCH
  unset DOCKERHUB_TAGS_PAGE1_FILE DOCKERHUB_TAGS_PAGE2_FILE
  unset DOCKERHUB_MALFORMED_COUNT DOCKERHUB_MALFORMED_COUNTER_FILE
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
  local rc=$?
  DIGEST_FILE="${GITHUB_WORKSPACE}/build/pushed_digests.txt"
  return "${rc}"
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
  assert_line "regctl tag delete test-registry/bareos-director-pgsql:24-alpine-amd64 --host reg=registry.example.com,tls=enabled --ignore-missing"
  assert_line "regctl tag delete test-registry/bareos-director-pgsql:24-alpine-arm64 --host reg=registry.example.com,tls=enabled --ignore-missing"
  assert_line "curl --fail -sS -H Content-Type: application/json --data-binary @- https://hub.docker.com/v2/auth/token"
  assert_line "curl -sS -o /dev/null -w %{http_code} -X DELETE -H @[^ ]+ https://hub.docker.com/v2/repositories/darkvex/bareos-director-pgsql/tags/24-alpine-amd64/"
  assert_line "curl -sS -o /dev/null -w %{http_code} -X DELETE -H @[^ ]+ https://hub.docker.com/v2/repositories/darkvex/bareos-director-pgsql/tags/24-alpine-arm64/"

  if grep -qwE "pass|dhpass" "${CALL_LOG}"; then
    fail "secret found in argv logged to CALL_LOG"
  fi
  if grep -qw "jwt" "${CALL_LOG}"; then
    fail "JWT value found in argv logged to CALL_LOG"
  fi

  # Fix (A): ephemeral per-arch alpine build tags must never be recorded,
  # since they're scaffolding deleted a few lines later — recording them
  # would make the later cosign signing step sign digests about to be gone.
  assert_no_digest_line_for "test-registry/bareos-director-pgsql:24-alpine-amd64"
  assert_no_digest_line_for "test-registry/bareos-director-pgsql:24-alpine-arm64"
  assert_no_digest_line_for "darkvex/bareos-director-pgsql:24-alpine-amd64"
  assert_no_digest_line_for "darkvex/bareos-director-pgsql:24-alpine-arm64"
  assert_digest_line_count 6
  assert_digest_line "test-registry/bareos-director-pgsql" "test-registry/bareos-director-pgsql:24-ubuntu"
  assert_digest_line "darkvex/bareos-director-pgsql" "darkvex/bareos-director-pgsql:24-ubuntu"
  assert_digest_line "test-registry/bareos-director-pgsql" "test-registry/bareos-director-pgsql:24"
  assert_digest_line "darkvex/bareos-director-pgsql" "darkvex/bareos-director-pgsql:24"
  assert_digest_line "test-registry/bareos-director-pgsql" "test-registry/bareos-director-pgsql:24-alpine"
  assert_digest_line "darkvex/bareos-director-pgsql" "darkvex/bareos-director-pgsql:24-alpine"
  if grep -qE ':[^/@]*@sha256:' "${DIGEST_FILE}"; then
    fail "digest line still carries a tag before the @ separator"
  fi
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

  assert_no_digest_line_for "test-registry/bareos-director-pgsql:24-alpine-amd64"
  assert_no_digest_line_for "test-registry/bareos-director-pgsql:24-alpine-arm64"
  assert_digest_line "test-registry/bareos-director-pgsql" "test-registry/bareos-director-pgsql:24-ubuntu"
  assert_digest_line "test-registry/bareos-director-pgsql" "test-registry/bareos-director-pgsql:24"
  assert_digest_line "test-registry/bareos-director-pgsql" "test-registry/bareos-director-pgsql:24-alpine"
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

  assert_no_digest_line_for "test-registry/bareos-director-pgsql:24-alpine"
  assert_digest_line "test-registry/bareos-director-pgsql" "test-registry/bareos-director-pgsql:24-ubuntu"
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
  assert_line "docker login -u dhuser --password-stdin"
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

scenario_wiz_scan_failure() {
  echo "--- scenario (f): wiz scan failure blocks publish ---"
  setup_fixture
  reset_env
  base_env
  export INPUT_DOCKERHUB_USER="dhuser"
  export INPUT_DOCKERHUB_PASS="dhpass"
  export FAIL_WIZ_SCAN="24-alpine-amd64"

  run_entrypoint
  local rc=$?

  assert_eq "${rc}" "1" "exit code"
  assert_no_line "docker push test-registry/bareos-director-pgsql:24-alpine-amd64"
  assert_no_line "docker push darkvex/bareos-director-pgsql:24-alpine-amd64"
  assert_line "docker push test-registry/bareos-director-pgsql:24-alpine-arm64"
  assert_line "docker push darkvex/bareos-director-pgsql:24-alpine-arm64"
  assert_line "docker push test-registry/bareos-director-pgsql:24-ubuntu"
  assert_line "docker push darkvex/bareos-director-pgsql:24-ubuntu"
  assert_line "docker push test-registry/bareos-director-pgsql:24"
  assert_line "docker push darkvex/bareos-director-pgsql:24"
  assert_line "docker manifest create test-registry/bareos-director-pgsql:24-alpine test-registry/bareos-director-pgsql:24-alpine-arm64"
  assert_line "docker manifest push test-registry/bareos-director-pgsql:24-alpine"
  assert_line "docker manifest create darkvex/bareos-director-pgsql:24-alpine darkvex/bareos-director-pgsql:24-alpine-arm64"
  assert_line "docker manifest push darkvex/bareos-director-pgsql:24-alpine"
  assert_no_line "regctl tag delete test-registry/bareos-director-pgsql:24-alpine-amd64 --host reg=registry.example.com,tls=enabled --ignore-missing"
  assert_line "regctl tag delete test-registry/bareos-director-pgsql:24-alpine-arm64 --host reg=registry.example.com,tls=enabled --ignore-missing"
  assert_no_line "curl -sS -o /dev/null -w %{http_code} -X DELETE -H @[^ ]+ https://hub.docker.com/v2/repositories/darkvex/bareos-director-pgsql/tags/24-alpine-amd64/"
  assert_line "curl -sS -o /dev/null -w %{http_code} -X DELETE -H @[^ ]+ https://hub.docker.com/v2/repositories/darkvex/bareos-director-pgsql/tags/24-alpine-arm64/"

  assert_digest_line_count 6
  assert_no_digest_line_for "test-registry/bareos-director-pgsql:24-alpine-amd64"
  assert_no_digest_line_for "darkvex/bareos-director-pgsql:24-alpine-amd64"
  assert_no_digest_line_for "test-registry/bareos-director-pgsql:24-alpine-arm64"
  assert_no_digest_line_for "darkvex/bareos-director-pgsql:24-alpine-arm64"
  assert_digest_line "test-registry/bareos-director-pgsql" "test-registry/bareos-director-pgsql:24-ubuntu"
  assert_digest_line "darkvex/bareos-director-pgsql" "darkvex/bareos-director-pgsql:24-ubuntu"
  assert_digest_line "test-registry/bareos-director-pgsql" "test-registry/bareos-director-pgsql:24"
  assert_digest_line "darkvex/bareos-director-pgsql" "darkvex/bareos-director-pgsql:24"
  assert_digest_line "test-registry/bareos-director-pgsql" "test-registry/bareos-director-pgsql:24-alpine"
  assert_digest_line "darkvex/bareos-director-pgsql" "darkvex/bareos-director-pgsql:24-alpine"
}

scenario_prune_orphaned_sig_att_tags() {
  echo "--- scenario (g): prune orphaned cosign sig/att tags ---"
  setup_fixture
  reset_env
  base_env
  export INPUT_DOCKERHUB_USER="dhuser"
  export INPUT_DOCKERHUB_PASS="dhpass"

  # Primary registry: seed a tag list for the repo this run touches with a
  # real tag ("24") whose digest (from the fake `regctl image digest`) makes
  # one sig/att pair live, a second sig/att pair that matches no real tag's
  # digest at all (orphaned — this is also what a retained-but-unbuilt
  # version like v22 looks like: live tag, no corresponding entry in this
  # run's pushed_digests.txt), and an unrelated real tag that must never be
  # considered for deletion.
  primary_live_hex=$(fake_digest_for "test-registry/bareos-director-pgsql:24")
  primary_orphan_hex=$(printf '%s' "primary-orphan-fixture" | sha256sum | cut -d' ' -f1)
  REGCTL_TAGS_DIR="${WORKDIR}/regctl_tags"
  mkdir -p "${REGCTL_TAGS_DIR}"
  cat > "${REGCTL_TAGS_DIR}/test-registry_bareos-director-pgsql.txt" <<TAGS
24
latest
sha256-${primary_live_hex}.sig
sha256-${primary_live_hex}.att
sha256-${primary_orphan_hex}.sig
sha256-${primary_orphan_hex}.att
TAGS
  export REGCTL_TAGS_DIR

  # Docker Hub: same idea, but the live digest comes straight from the tag
  # list response's own "digest" field (no extra digest lookup call needed
  # there), and the fixture is paginated across two GET responses to prove
  # deletes happen only after every page has been collected.
  dh_live_hex=$(printf '%s' "dockerhub-live-fixture" | sha256sum | cut -d' ' -f1)
  dh_orphan_hex=$(printf '%s' "dockerhub-orphan-fixture" | sha256sum | cut -d' ' -f1)
  DOCKERHUB_TAGS_PAGE1_FILE="${WORKDIR}/dockerhub_tags_page1.json"
  DOCKERHUB_TAGS_PAGE2_FILE="${WORKDIR}/dockerhub_tags_page2.json"
  cat > "${DOCKERHUB_TAGS_PAGE1_FILE}" <<JSON
{"results":[{"name":"24","digest":"sha256:${dh_live_hex}"},{"name":"sha256-${dh_live_hex}.sig","digest":"sha256:0000000000000000000000000000000000000000000000000000000000000000"}],"next":"https://hub.docker.com/v2/repositories/darkvex/bareos-director-pgsql/tags/?page_size=100&page=2"}
JSON
  cat > "${DOCKERHUB_TAGS_PAGE2_FILE}" <<JSON
{"results":[{"name":"sha256-${dh_orphan_hex}.att","digest":"sha256:1111111111111111111111111111111111111111111111111111111111111111"}],"next":null}
JSON
  export DOCKERHUB_TAGS_PAGE1_FILE DOCKERHUB_TAGS_PAGE2_FILE

  run_entrypoint
  local rc=$?

  assert_eq "${rc}" "0" "exit code"

  # The live set is built by querying every real (non sig/att) tag's digest...
  assert_line "regctl image digest test-registry/bareos-director-pgsql:24 --host reg=registry.example.com,tls=enabled"
  assert_line "regctl image digest test-registry/bareos-director-pgsql:latest --host reg=registry.example.com,tls=enabled"

  # Orphans get deleted...
  assert_line "regctl tag delete test-registry/bareos-director-pgsql:sha256-${primary_orphan_hex}\.sig --host reg=registry.example.com,tls=enabled --ignore-missing"
  assert_line "regctl tag delete test-registry/bareos-director-pgsql:sha256-${primary_orphan_hex}\.att --host reg=registry.example.com,tls=enabled --ignore-missing"
  assert_line "curl -sS -o /dev/null -w %{http_code} -X DELETE -H @[^ ]+ https://hub.docker.com/v2/repositories/darkvex/bareos-director-pgsql/tags/sha256-${dh_orphan_hex}\.att/"

  # ...live sig/att tags and unrelated real tags never do.
  assert_no_line "regctl tag delete test-registry/bareos-director-pgsql:sha256-${primary_live_hex}\.sig --host reg=registry.example.com,tls=enabled --ignore-missing"
  assert_no_line "regctl tag delete test-registry/bareos-director-pgsql:sha256-${primary_live_hex}\.att --host reg=registry.example.com,tls=enabled --ignore-missing"
  assert_no_line "regctl tag delete test-registry/bareos-director-pgsql:latest --host reg=registry.example.com,tls=enabled --ignore-missing"
  assert_no_line "regctl tag delete test-registry/bareos-director-pgsql:24 --host reg=registry.example.com,tls=enabled --ignore-missing"
  assert_no_line "curl -sS -o /dev/null -w %{http_code} -X DELETE -H @[^ ]+ https://hub.docker.com/v2/repositories/darkvex/bareos-director-pgsql/tags/sha256-${dh_live_hex}\.sig/"
  assert_no_line "curl -sS -o /dev/null -w %{http_code} -X DELETE -H @[^ ]+ https://hub.docker.com/v2/repositories/darkvex/bareos-director-pgsql/tags/24/"

  if grep -qE "^curl .*-X DELETE" "${CALL_LOG}"; then
    dh_delete_count=$(grep -cE "^curl .*-X DELETE.*hub\.docker\.com" "${CALL_LOG}")
    # 2 rm_tags_dockerhub deletes (alpine-amd64/arm64 build-tag cleanup) + 1 pruned orphan.
    assert_eq "${dh_delete_count}" "3" "Docker Hub DELETE call count"
  else
    fail "expected at least one Docker Hub DELETE call"
  fi

  # Regression pin: the Docker Hub prune loop must authenticate fresh, not
  # reuse the token minted for the earlier rm_tags_dockerhub cleanup — a
  # live run observed that reused token expiring by the time the (much
  # slower) primary-registry prune loop finished, silently no-opping the
  # entire Docker Hub prune. Two separate token fetches proves this can't
  # regress.
  auth_token_fetches=$(grep -cE "^curl --fail -sS -H Content-Type: application/json --data-binary @- https://hub\.docker\.com/v2/auth/token\$" "${CALL_LOG}")
  assert_eq "${auth_token_fetches}" "2" "Docker Hub auth token fetches"
}

scenario_prune_skipped_on_failed_run() {
  echo "--- scenario (h): prune skipped when the run had errors ---"
  setup_fixture
  reset_env
  base_env
  export FAIL_PUSH_MATCH="24-alpine-amd64"

  # Seed the exact same orphan fixture as scenario (g). If prune ran despite
  # the failed push above, it would delete these.
  primary_live_hex=$(fake_digest_for "test-registry/bareos-director-pgsql:24")
  primary_orphan_hex=$(printf '%s' "primary-orphan-fixture" | sha256sum | cut -d' ' -f1)
  REGCTL_TAGS_DIR="${WORKDIR}/regctl_tags"
  mkdir -p "${REGCTL_TAGS_DIR}"
  cat > "${REGCTL_TAGS_DIR}/test-registry_bareos-director-pgsql.txt" <<TAGS
24
sha256-${primary_live_hex}.sig
sha256-${primary_orphan_hex}.sig
TAGS
  export REGCTL_TAGS_DIR

  run_entrypoint
  local rc=$?

  assert_eq "${rc}" "1" "exit code"
  if grep -qE '^regctl tag delete [^ ]+:sha256-' "${CALL_LOG}"; then
    fail "prune deleted a sig/att tag on a run with errors"
  fi
  if grep -qE '^regctl (tag ls|image digest)' "${CALL_LOG}"; then
    fail "prune inspected tags at all on a run with errors; it should have been skipped entirely"
  fi
}

scenario_prune_fails_closed_on_unresolvable_digest() {
  echo "--- scenario (i): prune fails closed when a live tag's digest can't be resolved ---"
  setup_fixture
  reset_env
  base_env
  export INPUT_DOCKERHUB_USER="dhuser"
  export INPUT_DOCKERHUB_PASS="dhpass"

  # Primary registry: the digest lookup for "latest" fails (transient error,
  # auth blip, whatever) — the live set for this repo can never be complete,
  # so this repo's prune must be skipped entirely, even though an obvious
  # orphan ("sha256-<hex>.att", matching no real tag) is sitting right there.
  export REGCTL_DIGEST_FAIL_MATCH="bareos-director-pgsql:latest"
  primary_orphan_hex=$(printf '%s' "primary-orphan-fixture-i" | sha256sum | cut -d' ' -f1)
  REGCTL_TAGS_DIR="${WORKDIR}/regctl_tags"
  mkdir -p "${REGCTL_TAGS_DIR}"
  cat > "${REGCTL_TAGS_DIR}/test-registry_bareos-director-pgsql.txt" <<TAGS
24
latest
sha256-${primary_orphan_hex}.att
TAGS
  export REGCTL_TAGS_DIR

  # Docker Hub: same idea via a real tag whose digest field is null.
  dh_orphan_hex=$(printf '%s' "dockerhub-orphan-fixture-i" | sha256sum | cut -d' ' -f1)
  DOCKERHUB_TAGS_PAGE1_FILE="${WORKDIR}/dockerhub_tags_page1.json"
  cat > "${DOCKERHUB_TAGS_PAGE1_FILE}" <<JSON
{"results":[{"name":"24","digest":null},{"name":"sha256-${dh_orphan_hex}.att","digest":"sha256:2222222222222222222222222222222222222222222222222222222222222222"}],"next":null}
JSON
  export DOCKERHUB_TAGS_PAGE1_FILE

  run_entrypoint
  local rc=$?

  assert_eq "${rc}" "0" "exit code"
  if grep -qE "^regctl tag delete [^ ]+:sha256-" "${CALL_LOG}"; then
    fail "primary registry: prune deleted a sig/att tag from a repo whose live set couldn't be fully resolved"
  fi
  if grep -qE "^curl .*-X DELETE.*hub\.docker\.com.*/tags/sha256-" "${CALL_LOG}"; then
    fail "Docker Hub: prune deleted a sig/att tag from a repo whose live set couldn't be fully resolved"
  fi
  if ! grep -qF "could not resolve digest for test-registry/bareos-director-pgsql:latest" "${WORKDIR}/output.log"; then
    fail "expected a warning about the unresolvable primary-registry digest"
  fi
  if ! grep -qF "darkvex/bareos-director-pgsql:24 has no resolvable digest" "${WORKDIR}/output.log"; then
    fail "expected a warning about the unresolvable Docker Hub digest"
  fi
}

scenario_prune_dockerhub_retries_malformed_response() {
  echo "--- scenario (j): prune retries a malformed Docker Hub tags response and succeeds ---"
  setup_fixture
  reset_env
  base_env
  export INPUT_DOCKERHUB_USER="dhuser"
  export INPUT_DOCKERHUB_PASS="dhpass"

  # Simulate the transient case actually observed in production: the Hub
  # API returns a bare `null` body (not {"results": [...], ...}) for the
  # first 2 attempts, then a normal response on the 3rd.
  export DOCKERHUB_MALFORMED_COUNT=2
  DOCKERHUB_MALFORMED_COUNTER_FILE="${WORKDIR}/dockerhub_malformed_counter"
  export DOCKERHUB_MALFORMED_COUNTER_FILE
  dh_orphan_hex=$(printf '%s' "dockerhub-orphan-fixture-j" | sha256sum | cut -d' ' -f1)
  DOCKERHUB_TAGS_PAGE1_FILE="${WORKDIR}/dockerhub_tags_page1.json"
  cat > "${DOCKERHUB_TAGS_PAGE1_FILE}" <<JSON
{"results":[{"name":"24","digest":"sha256:3333333333333333333333333333333333333333333333333333333333333333"},{"name":"sha256-${dh_orphan_hex}.att","digest":"sha256:4444444444444444444444444444444444444444444444444444444444444444"}],"next":null}
JSON
  export DOCKERHUB_TAGS_PAGE1_FILE

  run_entrypoint
  local rc=$?

  assert_eq "${rc}" "0" "exit code"
  assert_line "curl -sS -o /dev/null -w %{http_code} -X DELETE -H @[^ ]+ https://hub.docker.com/v2/repositories/darkvex/bareos-director-pgsql/tags/sha256-${dh_orphan_hex}\.att/"
  # No warning on a retry that eventually succeeds — only prove the retries
  # actually happened (3 GET attempts against the tags-list endpoint).
  get_attempts=$(grep -cE "^curl -sS -H @[^ ]+ https://hub\.docker\.com/v2/repositories/darkvex/bareos-director-pgsql/tags/\?page_size=100\$" "${CALL_LOG}")
  assert_eq "${get_attempts}" "3" "Docker Hub tags-list GET attempts"
}

scenario_prune_dockerhub_fails_closed_after_exhausting_retries() {
  echo "--- scenario (k): prune fails closed after exhausting Docker Hub retries ---"
  setup_fixture
  reset_env
  base_env
  export INPUT_DOCKERHUB_USER="dhuser"
  export INPUT_DOCKERHUB_PASS="dhpass"

  # Always malformed — never recovers within the retry budget.
  export DOCKERHUB_MALFORMED_COUNT=999
  DOCKERHUB_MALFORMED_COUNTER_FILE="${WORKDIR}/dockerhub_malformed_counter"
  export DOCKERHUB_MALFORMED_COUNTER_FILE

  run_entrypoint
  local rc=$?

  assert_eq "${rc}" "0" "exit code"
  if grep -qE "^curl .*-X DELETE.*hub\.docker\.com.*/tags/sha256-" "${CALL_LOG}"; then
    fail "prune deleted a Docker Hub sig/att tag despite every page fetch being malformed"
  fi
  if ! grep -qF "unexpected Docker Hub tags response for darkvex/bareos-director-pgsql after 3 attempts" "${WORKDIR}/output.log"; then
    fail "expected a warning that retries were exhausted"
  fi
}

scenario_all_success
scenario_single_failed_push
scenario_failed_manifest_create
scenario_primary_login_failure
scenario_dockerhub_login_failure
scenario_wiz_scan_failure
scenario_prune_orphaned_sig_att_tags
scenario_prune_skipped_on_failed_run
scenario_prune_fails_closed_on_unresolvable_digest
scenario_prune_dockerhub_retries_malformed_response
scenario_prune_dockerhub_fails_closed_after_exhausting_retries

if [[ "${FAILURES}" -eq 0 ]]; then
  echo "All scenarios passed."
  exit 0
else
  echo "${FAILURES} assertion(s) failed."
  exit 1
fi
