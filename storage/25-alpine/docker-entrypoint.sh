#!/usr/bin/env ash
set -eu

cfg_quote() { printf '%s' "$1" | sed -e 's/[\\"]/\\&/g'; }
sed_repl() { printf '%s' "$1" | sed -e 's/[\\&#]/\\&/g'; }
require_no_newline() {
  case "$1" in
    *"
"*)
      echo "$2 must not contain a newline" >&2
      exit 1
      ;;
  esac
}

bareos_sd_config="/etc/bareos/bareos-sd.d/director/bareos-dir.conf"
bareos_sd_mon_config="/etc/bareos/bareos-sd.d/director/bareos-mon.conf"

resolve_required_password() {
  secret_name=$1
  secret_direct=$2
  secret_file=$3
  RESOLVED_PASSWORD=

  if [ -n "$secret_direct" ] && [ -n "$secret_file" ]; then
    echo "docker-entrypoint: ${secret_name} and ${secret_name}_FILE must not both be set" >&2
    return 1
  fi

  if [ -n "$secret_file" ]; then
    if [ ! -r "$secret_file" ]; then
      echo "docker-entrypoint: ${secret_name}_FILE does not name a readable file" >&2
      return 1
    fi
    RESOLVED_PASSWORD=$(cat "$secret_file" 2>/dev/null) || {
      echo "docker-entrypoint: failed to read ${secret_name}_FILE" >&2
      return 1
    }
  else
    RESOLVED_PASSWORD=$secret_direct
  fi

  case "$RESOLVED_PASSWORD" in
    '')
      echo "docker-entrypoint: ${secret_name} must not be empty (set ${secret_name} or ${secret_name}_FILE)" >&2
      return 1
      ;;
    *"
"*)
      echo "docker-entrypoint: ${secret_name} must not contain a newline" >&2
      return 1
      ;;
    'ThisIsMySecretDBp4ssw0rd'|'ThisIsMySecretDBAdm1np4ssw0rd'|'ThisIsMySecretSDp4ssw0rd'|'ThisIsMySecretFDp4ssw0rd'|'ThisIsMySecretUIp4ssw0rd')
      echo "docker-entrypoint: ${secret_name} still has the retired example value from .env.dist - set a real password" >&2
      return 1
      ;;
  esac
}

resolve_required_password BAREOS_SD_PASSWORD "${BAREOS_SD_PASSWORD:-}" "${BAREOS_SD_PASSWORD_FILE:-}" || exit 1
BAREOS_SD_PASSWORD=$RESOLVED_PASSWORD

if [ ! -f /etc/bareos/bareos-config.control ]; then
  tar xfz /bareos-sd.tgz --backup=simple --suffix=.before-control

  # Update bareos-storage configs
  bareos_sd_password_repl="$(sed_repl "$(cfg_quote "${BAREOS_SD_PASSWORD:-}")")"
  sed -i 's#Password = .*#Password = "'"${bareos_sd_password_repl}"'"#' "$bareos_sd_config"

  # Bareos >=24 rejects the empty Password the bundled bareos-mon.conf ships
  # with (startup fails: "Empty Password not allowed in Resource bareos-mon").
  sed -i 's#Password = .*#Password = "'"${bareos_sd_password_repl}"'"#' "$bareos_sd_mon_config"

  # Control file
  touch /etc/bareos/bareos-config.control
fi

# Fix permissions
find /var/lib/bareos ! -user bareos -exec chown bareos {} \;
find /etc/bareos/bareos-sd.d ! -user bareos -exec chown bareos {} \;
find /dev -regex "/dev/[n]?st[0-9]+" ! -user bareos -exec chown bareos {} \;
find /dev -regex "/dev/tape/.*" ! -user bareos -exec chown bareos {} \;

# Run Dockerfile CMD
exec "$@"
