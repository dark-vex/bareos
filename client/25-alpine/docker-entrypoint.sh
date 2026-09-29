#!/usr/bin/env bash
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

bareos_fd_config="/etc/bareos/bareos-fd.d/director/bareos-dir.conf"
bareos_fd_mon_config="/etc/bareos/bareos-fd.d/director/bareos-mon.conf"

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

if [ "${FORCE_ROOT:-}" = true ]; then
  BAREOS_DAEMON_USER='root'
  BAREOS_DAEMON_GROUP='root'
fi

if [ "$(id -u)" = '0' ]; then
  if [ -n "${PUID:-}" ]; then
    usermod -u "${PUID}" "${BAREOS_DAEMON_USER}"
  fi
  if [ -n "${PGID:-}" ]; then
    groupmod -g "${PGID}" "${BAREOS_DAEMON_GROUP}"
  fi
  resolve_required_password BAREOS_FD_PASSWORD "${BAREOS_FD_PASSWORD:-}" "${BAREOS_FD_PASSWORD_FILE:-}" || exit 1
  BAREOS_FD_PASSWORD=$RESOLVED_PASSWORD

  if [ ! -f /etc/bareos/bareos-config.control ]; then
    tar xzf /bareos-fd.tgz --backup=simple --suffix=.before-control

    # Force client/file daemon password
    bareos_fd_password_repl="$(sed_repl "$(cfg_quote "${BAREOS_FD_PASSWORD:-}")")"
    sed -i 's#Password = .*#Password = "'"${bareos_fd_password_repl}"'"#' "$bareos_fd_config"

    # Bareos >=24 rejects the empty Password the bundled bareos-mon.conf
    # ships with (startup fails: "Empty Password not allowed in Resource
    # bareos-mon").
    sed -i 's#Password = .*#Password = "'"${bareos_fd_password_repl}"'"#' "$bareos_fd_mon_config"

    # Control file
    touch /etc/bareos/bareos-config.control
  fi

  # Fix permissions
  find /etc/bareos ! -user "${BAREOS_DAEMON_USER}" -exec chown "${BAREOS_DAEMON_USER}:${BAREOS_DAEMON_GROUP}" {} \;
  chown "${BAREOS_DAEMON_USER}:${BAREOS_DAEMON_GROUP}" /run/bareos /var/log/bareos /var/lib/bareos

  # Su-exec
  if [ "${BAREOS_DAEMON_USER}" != 'root' ]; then
    exec su-exec "${BAREOS_DAEMON_USER}" "${BASH_SOURCE[0]}" "$@"
  fi
fi

exec "$@"
