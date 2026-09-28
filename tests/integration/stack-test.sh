#!/usr/bin/env bash

# shellcheck disable=SC2329

set -euo pipefail

: "${DIR_IMAGE:?DIR_IMAGE is required}"
: "${SD_IMAGE:?SD_IMAGE is required}"
: "${FD_IMAGE:?FD_IMAGE is required}"
: "${WEBUI_IMAGE:?WEBUI_IMAGE is required}"
: "${API_IMAGE:?API_IMAGE is required}"
: "${PROJECT:?PROJECT is required}"

PG_IMAGE="${PG_IMAGE:-postgres:17-alpine@sha256:b0f9560a2de083e2cc7382e75f808c7381a32852a7ec49117deedb300e552b24}"
CURL_IMAGE="${CURL_IMAGE:-curlimages/curl:8.22.0@sha256:58adaa4e8dca9c988bae2aba4ab3434a0bb2da16bbe3f92dec39ec7785166777}"
FLAVOR="${FLAVOR:-alpine}"
DIR_INIT_TIMEOUT="${DIR_INIT_TIMEOUT:-180}"
JOB_TIMEOUT="${JOB_TIMEOUT:-180}"

case "$FLAVOR" in
  alpine|ubuntu) ;;
  *)
    echo "FLAVOR must be alpine or ubuntu, got: $FLAVOR" >&2
    exit 1
    ;;
esac

NET="${PROJECT}-net"
DB="${PROJECT}-db"
SD="${PROJECT}-sd"
FD="${PROJECT}-fd"
DIR="${PROJECT}-dir"
WEBUI="${PROJECT}-webui"
PHPFPM="${PROJECT}-phpfpm"
API="${PROJECT}-api"
CURLER="${PROJECT}-curl"

VOL_DB="${PROJECT}-vol-db"
VOL_DIR_CFG="${PROJECT}-vol-dir-cfg"
VOL_DIR_DATA="${PROJECT}-vol-dir-data"
VOL_SD_CFG="${PROJECT}-vol-sd-cfg"
VOL_SD_DATA="${PROJECT}-vol-sd-data"
VOL_FD_CFG="${PROJECT}-vol-fd-cfg"
VOL_FD_DATA="${PROJECT}-vol-fd-data"
VOL_WEBUI_CFG="${PROJECT}-vol-webui-cfg"
VOL_WEBUI_DATA="${PROJECT}-vol-webui-data"

ALL_CONTAINERS=("$DB" "$SD" "$FD" "$DIR" "$WEBUI" "$PHPFPM" "$API" "$CURLER")
ALL_VOLUMES=(
  "$VOL_DB" "$VOL_DIR_CFG" "$VOL_DIR_DATA" "$VOL_SD_CFG" "$VOL_SD_DATA"
  "$VOL_FD_CFG" "$VOL_FD_DATA" "$VOL_WEBUI_CFG" "$VOL_WEBUI_DATA"
)

DB_PASSWORD='db#pass '"'"' "\:&end'
DB_ADMIN_PASSWORD='adm"pass '"'"' #\:& end2'
BAREOS_SD_PASSWORD='sd&pass '"'"' "#\:end3'
BAREOS_FD_PASSWORD='fd\pass '"'"' "#&:end4'
BAREOS_WEBUI_PASSWORD='ui:pass '"'"' "#&\end5'
DB_ADMIN_USER='postgres'
DB_USER='bareos'
DB_NAME='bareos'

STATE_DIR="/tmp/${PROJECT}-itest-state"
mkdir -p "$STATE_DIR"

FAILED=0

log() { printf '%s\n' "$*"; }
pass() { log "PASS: $*"; }
fail() { log "FAIL: $*"; FAILED=1; }

dump_logs() {
  log "---- container logs (failure diagnostics) ----"
  for c in "${ALL_CONTAINERS[@]}"; do
    if docker inspect "$c" >/dev/null 2>&1; then
      log "==== docker logs $c ===="
      docker logs "$c" 2>&1 | tail -n 300 || true
    fi
  done
  log "---- end container logs ----"
}

cleanup() {
  local rc=$?
  if [ "$rc" -ne 0 ]; then
    dump_logs
    if [ "${KEEP_ON_FAILURE:-0}" = "1" ]; then
      log "KEEP_ON_FAILURE=1: leaving containers/network/volumes in place for inspection."
      return
    fi
  fi
  for c in "${ALL_CONTAINERS[@]}"; do
    docker rm -f "$c" >/dev/null 2>&1 || true
  done
  docker network rm "$NET" >/dev/null 2>&1 || true
  for v in "${ALL_VOLUMES[@]}"; do
    docker volume rm "$v" >/dev/null 2>&1 || true
  done
  rm -rf "$STATE_DIR"
}
trap cleanup EXIT

step() {
  local desc="$1"
  shift
  log "---- STEP: $desc ----"
  if "$@"; then
    pass "$desc"
  else
    fail "$desc"
    exit 1
  fi
}

bconsole_cmd() {
  {
    for c in "$@"; do
      printf '%s\n' "$c"
    done
  } | timeout 60 docker exec -i "$DIR" bconsole
}

wait_for() {
  local desc="$1" timeout="$2"
  shift 2
  local waited=0
  while [ "$waited" -lt "$timeout" ]; do
    if "$@" >/dev/null 2>&1; then
      return 0
    fi
    sleep 3
    waited=$((waited + 3))
  done
  log "timed out after ${timeout}s waiting for: $desc"
  return 1
}

job_status() {
  local jobid="$1"
  bconsole_cmd "llist jobid=${jobid}" 2>/dev/null \
    | awk '/^ *jobstatus:/ && !found { sub(/^ *jobstatus: */, ""); print; found = 1 }'
}

wait_job_terminated() {
  local jobid="$1" timeout="$2"
  local waited=0 st
  while [ "$waited" -lt "$timeout" ]; do
    st="$(job_status "$jobid" || true)"
    case "$st" in
      T) return 0 ;;
      f|E|A) log "job $jobid ended with status $st"; return 1 ;;
    esac
    sleep 3
    waited=$((waited + 3))
  done
  log "timed out after ${timeout}s waiting for job $jobid to terminate (last status: ${st:-unknown})"
  return 1
}

create_network_and_db() {
  docker network create "$NET" >/dev/null
  docker volume create "$VOL_DB" >/dev/null
  docker run -d --name "$DB" --network "$NET" --network-alias bareos-db \
    -e POSTGRES_USER="$DB_ADMIN_USER" \
    -e POSTGRES_PASSWORD="$DB_ADMIN_PASSWORD" \
    -e POSTGRES_INITDB_ARGS='--encoding=SQL_ASCII' \
    -v "${VOL_DB}:/var/lib/postgresql/data" \
    "$PG_IMAGE" >/dev/null
  wait_for "postgres ready" 90 \
    docker exec "$DB" pg_isready -U "$DB_ADMIN_USER"
}

start_sd() {
  docker volume create "$VOL_SD_CFG" >/dev/null
  docker volume create "$VOL_SD_DATA" >/dev/null
  docker run -d --name "$SD" --network "$NET" --network-alias bareos-sd \
    -e BAREOS_SD_PASSWORD="$BAREOS_SD_PASSWORD" \
    -v "${VOL_SD_CFG}:/etc/bareos" \
    -v "${VOL_SD_DATA}:/var/lib/bareos/archive" \
    "$SD_IMAGE" >/dev/null
}

start_fd() {
  docker volume create "$VOL_FD_CFG" >/dev/null
  docker volume create "$VOL_FD_DATA" >/dev/null
  docker run -d --name "$FD" --network "$NET" --network-alias bareos-fd \
    -e BAREOS_FD_PASSWORD="$BAREOS_FD_PASSWORD" \
    -e FORCE_ROOT=false \
    -v "${VOL_FD_CFG}:/etc/bareos" \
    -v "${VOL_FD_DATA}:/var/lib/bareos-director" \
    "$FD_IMAGE" >/dev/null
}

start_dir() {
  local extra_env=("$@")
  docker volume create "$VOL_DIR_CFG" >/dev/null
  docker volume create "$VOL_DIR_DATA" >/dev/null
  docker run -d --name "$DIR" --network "$NET" --network-alias bareos-dir \
    -e DB_HOST=bareos-db \
    -e DB_PORT=5432 \
    -e DB_NAME="$DB_NAME" \
    -e DB_USER="$DB_USER" \
    -e DB_PASSWORD="$DB_PASSWORD" \
    -e DB_ADMIN_USER="$DB_ADMIN_USER" \
    -e DB_ADMIN_PASSWORD="$DB_ADMIN_PASSWORD" \
    -e BAREOS_SD_HOST=bareos-sd \
    -e BAREOS_SD_PASSWORD="$BAREOS_SD_PASSWORD" \
    -e BAREOS_FD_HOST=bareos-fd \
    -e BAREOS_FD_PASSWORD="$BAREOS_FD_PASSWORD" \
    -e BAREOS_WEBUI_PASSWORD="$BAREOS_WEBUI_PASSWORD" \
    -e SMTP_HOST=smtp.invalid:8025 \
    -e ADMIN_MAIL='admin@example.com' \
    -e WEBHOOK_NOTIFICATION=false \
    "${extra_env[@]}" \
    -v "${VOL_DIR_CFG}:/etc/bareos" \
    -v "${VOL_DIR_DATA}:/var/lib/bareos" \
    "$DIR_IMAGE" >/dev/null
}

start_sd_fd_dir_init() {
  start_sd
  start_fd
  start_dir -e DB_INIT=true -e DB_UPDATE=false
}

start_webui() {
  docker volume create "$VOL_WEBUI_CFG" >/dev/null
  docker volume create "$VOL_WEBUI_DATA" >/dev/null
  if [ "$FLAVOR" = "alpine" ]; then
    docker run -d --name "$PHPFPM" --network "$NET" --network-alias php-fpm \
      -v "${VOL_WEBUI_CFG}:/etc/bareos-webui" \
      -v "${VOL_WEBUI_DATA}:/usr/share/bareos-webui" \
      --entrypoint /usr/local/sbin/php-fpm \
      --health-cmd "nc -z 127.0.0.1 9000" --health-interval=10s --health-timeout=5s --health-retries=5 --health-start-period=15s \
      "$WEBUI_IMAGE" >/dev/null
    docker run -d --name "$WEBUI" --network "$NET" --network-alias bareos-webui \
      -e BAREOS_DIR_HOST=bareos-dir \
      -e PHP_FPM_HOST=php-fpm \
      -e PHP_FPM_PORT=9000 \
      -v "${VOL_WEBUI_CFG}:/etc/bareos-webui" \
      -v "${VOL_WEBUI_DATA}:/usr/share/bareos-webui" \
      "$WEBUI_IMAGE" >/dev/null
  else
    docker run -d --name "$WEBUI" --network "$NET" --network-alias bareos-webui \
      -e BAREOS_DIR_HOST=bareos-dir \
      -e SERVER_STATS=yes \
      -v "${VOL_WEBUI_CFG}:/etc/bareos-webui" \
      "$WEBUI_IMAGE" >/dev/null
  fi
}

webui_port() {
  if [ "$FLAVOR" = "alpine" ]; then echo 9100; else echo 80; fi
}

webui_reachable() {
  local code
  code="$(docker run --rm --network "$NET" "$CURL_IMAGE" \
    -s -o /dev/null -w '%{http_code}' "http://bareos-webui:$(webui_port)/index.php/auth/login")"
  [ "$code" = "200" ]
}

start_api() {
  docker run -d --name "$API" --network "$NET" --network-alias bareos-api \
    -e BAREOS_DIR_HOST=bareos-dir \
    -e JWT_SECRET='jwt#secret '"'"' "\:&end6' \
    "$API_IMAGE" >/dev/null
}

api_reachable() {
  local code
  code="$(docker run --rm --network "$NET" "$CURL_IMAGE" \
    -s -o /dev/null -w '%{http_code}' "http://bareos-api:8000/docs")"
  [ "$code" = "200" ]
}

director_status_ok() {
  bconsole_cmd "status director" 2>/dev/null | grep -i "Daemon started" >/dev/null
}

storage_status_ok() {
  bconsole_cmd "status storage=File" 2>/dev/null | grep -i "Daemon started" >/dev/null
}

client_status_ok() {
  bconsole_cmd "status client=bareos-fd" 2>/dev/null | grep -i "Daemon started" >/dev/null
}

MARKER_NAME=""
MARKER_CONTENT=""

write_marker() {
  MARKER_NAME="itest-marker-${PROJECT}-${RANDOM}"
  MARKER_CONTENT="marker-$(date +%s)-${RANDOM}-${RANDOM}"
  docker exec -u root "$FD" sh -c \
    "printf '%s' '${MARKER_CONTENT}' > '/usr/sbin/${MARKER_NAME}'"
}

run_full_backup() {
  local out jobid
  out="$(bconsole_cmd "run job=backup-bareos-fd level=Full yes" 2>/dev/null)"
  jobid="$(printf '%s\n' "$out" | sed -n 's/.*JobId=\([0-9][0-9]*\).*/\1/p' | head -n1)"
  if [ -z "$jobid" ]; then
    log "could not determine backup jobid from output:"
    log "$out"
    return 1
  fi
  echo "$jobid" > "$STATE_DIR/backup-jobid"
  wait_job_terminated "$jobid" "$JOB_TIMEOUT"
}

backup_jobid() {
  cat "$STATE_DIR/backup-jobid"
}

run_restore() {
  local backup_id out jobid
  backup_id="$(backup_jobid)"
  out="$(bconsole_cmd "restore jobid=${backup_id}" "mark *" "done" "yes" 2>/dev/null)"
  jobid="$(printf '%s\n' "$out" | sed -n 's/.*Job queued. JobId=\([0-9][0-9]*\).*/\1/p' | tail -n1)"
  if [ -z "$jobid" ]; then
    log "could not determine restore jobid from output:"
    log "$out"
    return 1
  fi
  echo "$jobid" > "$STATE_DIR/restore-jobid"
  wait_job_terminated "$jobid" "$JOB_TIMEOUT"
}

restore_content_matches() {
  local content
  content="$(docker exec -u root "$FD" sh -c \
    "cat '/tmp/bareos-restores/usr/sbin/${MARKER_NAME}' 2>/dev/null" || true)"
  [ "$content" = "$MARKER_CONTENT" ]
}

webui_login_attempt() {
  local port="$1" password="$2"
  docker run --rm --network "$NET" -e URL="http://bareos-webui:${port}/index.php/auth/login" \
    -e PASSWORD="$password" --entrypoint sh "$CURL_IMAGE" -c '
      field() { tr ">" "\n" < /tmp/page | sed -n "s/.*name=\"$1\".*value=\"\([^\"]*\)\".*/\1/p" | head -n1; }
      curl -s -D /tmp/headers -o /tmp/page "$URL"
      sid=$(sed -n "s/^[Ss]et-[Cc]ookie: \(bareos=[^;]*\).*/\1/p" /tmp/headers | head -n1)
      curl -s -o /dev/null -w "%{http_code}" -H "Cookie: ${sid}" \
        --data-urlencode "director=$(field director)" \
        --data-urlencode "consolename=admin" \
        --data-urlencode "password=${PASSWORD}" \
        --data-urlencode "locale=en_EN" \
        --data-urlencode "csrf=$(field csrf)" \
        --data-urlencode "submit=Login" \
        "$URL"
    '
}

webui_login_ok() {
  local port code
  port="$(webui_port)"
  code="$(webui_login_attempt "$port" "$BAREOS_WEBUI_PASSWORD")"
  [ "$code" = "302" ]
}

webui_login_wrong_password_rejected() {
  local port code
  port="$(webui_port)"
  code="$(webui_login_attempt "$port" "definitely-wrong-password")"
  [ "$code" = "200" ]
}

api_token() {
  local password="$1"
  docker run --rm --network "$NET" "$CURL_IMAGE" \
    -s -X POST "http://bareos-api:8000/token" \
    --data-urlencode "username=admin" \
    --data-urlencode "password=${password}"
}

api_login_ok() {
  local resp token
  resp="$(api_token "$BAREOS_WEBUI_PASSWORD")"
  token="$(printf '%s' "$resp" | sed -n 's/.*"access_token":"\([^"]*\)".*/\1/p')"
  [ -n "$token" ] || { log "api token response: $resp"; return 1; }
  echo "$token" > "$STATE_DIR/api-token"
}

api_login_wrong_password_rejected() {
  local resp
  resp="$(api_token "definitely-wrong-password")"
  printf '%s' "$resp" | grep -i "incorrect\|unauthorized\|401" >/dev/null
}

api_query_ok() {
  local token resp
  token="$(cat "$STATE_DIR/api-token")"
  resp="$(docker run --rm --network "$NET" "$CURL_IMAGE" \
    -s -H "Authorization: Bearer ${token}" \
    "http://bareos-api:8000/control/clients")"
  printf '%s' "$resp" | grep -i "bareos-fd" >/dev/null
}

main() {
  step "network + postgres" create_network_and_db
  step "start storage daemon and file daemon" start_sd_fd_dir_init
  step "wait for director (status director)" \
    wait_for "director bconsole reachable" "$DIR_INIT_TIMEOUT" director_status_ok
  step "status storage=File" wait_for "storage daemon reachable via director" 180 storage_status_ok
  step "status client=bareos-fd" wait_for "file daemon reachable via director" 180 client_status_ok

  step "start webui${FLAVOR:+ ($FLAVOR)}" start_webui
  step "webui reachable" wait_for "webui http reachable" 180 webui_reachable

  step "start api" start_api
  step "api reachable" wait_for "api http reachable" 180 api_reachable

  step "write backup marker file on fd" write_marker
  step "run Full backup job" run_full_backup

  step "restore backup job" run_restore
  step "restored marker content matches" restore_content_matches

  step "webui login with correct password" webui_login_ok
  step "webui login with wrong password is rejected" webui_login_wrong_password_rejected

  step "api: obtain JWT with correct password" api_login_ok
  step "api: wrong password rejected" api_login_wrong_password_rejected
  step "api: authenticated query lists bareos-fd" api_query_ok

  step "restart director" docker restart "$DIR"
  step "director reachable again after restart" \
    wait_for "director bconsole reachable after restart" 180 director_status_ok
  step "no re-init happened after restart" wait_for "catalog kept across restart" 60 no_reinit_after_restart

  step "recreate director with DB_UPDATE=true" recreate_dir_with_db_update
  step "director reachable after DB_UPDATE" \
    wait_for "director bconsole reachable after DB_UPDATE" "$DIR_INIT_TIMEOUT" director_status_ok

  log ""
  log "ALL STEPS PASSED for PROJECT=${PROJECT} FLAVOR=${FLAVOR}"
}

no_reinit_after_restart() {
  [ "$(docker logs "$DIR" 2>&1 | grep -c 'Bareos DB init$')" = "1" ] \
    && [ "$(job_status "$(backup_jobid)")" = "T" ]
}

recreate_dir_with_db_update() {
  docker rm -f "$DIR" >/dev/null 2>&1 || true
  start_dir -e DB_INIT=false -e DB_UPDATE=true
}

main
exit "$FAILED"
