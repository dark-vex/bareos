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

require_no_newline "${BAREOS_DIR_HOST:-}" "BAREOS_DIR_HOST"

if [ ! -f /etc/bareos-webui/bareos-config.control ]; then
  tar xzf /bareos-webui.tgz --backup=simple --suffix=.before-control

  # Update bareos-webui config
  bareos_dir_host_repl="$(sed_repl "$(cfg_quote "${BAREOS_DIR_HOST:-}")")"
  sed -i 's#diraddress.*#diraddress = "'"${bareos_dir_host_repl}"'"#' \
    /etc/bareos-webui/directors.ini

  # Control file
  touch /etc/bareos-webui/bareos-config.control
fi

apache_conf="/etc/apache2/sites-available/000-default.conf"

# Set document root
sed -i "s#/var/www/html#/usr/share/bareos-webui/public#g" "$apache_conf"

# Enable Apache server stats
if [ "${SERVER_STATS:-}" = "yes" ]; then
  sed -i 's!#ServerName.*!Alias /server-status /var/www/dummy!' "$apache_conf"
fi

case "${1:-}" in
  */apache2ctl|apache2ctl)
    mkdir -p /run/php
    /usr/local/sbin/php-fpm --daemonize
    ;;
esac

# Run Dockerfile CMD
exec "$@"
