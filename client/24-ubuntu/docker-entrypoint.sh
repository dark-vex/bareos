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

require_no_newline "${BAREOS_FD_PASSWORD:-}" "BAREOS_FD_PASSWORD"

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
  chown -R "${BAREOS_DAEMON_USER}:${BAREOS_DAEMON_GROUP}" /var/lib/bareos /var/log/bareos

  # Drop privileges
  if [ "${BAREOS_DAEMON_USER}" != 'root' ]; then
    HOME="$(getent passwd "${BAREOS_DAEMON_USER}" | cut -d: -f6)" exec setpriv --reuid="${BAREOS_DAEMON_USER}" --regid="${BAREOS_DAEMON_GROUP}" --init-groups "$BASH_SOURCE" "$@"
  fi
fi

exec "$@"
