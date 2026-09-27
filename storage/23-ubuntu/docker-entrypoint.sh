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

bareos_sd_config="/etc/bareos/bareos-sd.d/director/bareos-dir.conf"

require_no_newline "${BAREOS_SD_PASSWORD:-}" "BAREOS_SD_PASSWORD"

if [ ! -f /etc/bareos/bareos-config.control ]; then
  tar xfz /bareos-sd.tgz --backup=simple --suffix=.before-control

  # Update bareos-storage configs
  bareos_sd_password_repl="$(sed_repl "$(cfg_quote "${BAREOS_SD_PASSWORD:-}")")"
  sed -i 's#Password = .*#Password = "'"${bareos_sd_password_repl}"'"#' "$bareos_sd_config"

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
