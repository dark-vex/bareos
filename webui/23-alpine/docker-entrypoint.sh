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

require_no_newline "${BAREOS_DIR_HOST:-}" "BAREOS_DIR_HOST"
require_no_newline "${PHP_FPM_HOST:-}" "PHP_FPM_HOST"
require_no_newline "${PHP_FPM_PORT:-}" "PHP_FPM_PORT"

if [ ! -f /etc/bareos-webui/bareos-config.control ]; then
  tar xfvz /bareos-webui-config.tgz

  # Update bareos-webui config
  bareos_dir_host_repl="$(sed_repl "$(cfg_quote "${BAREOS_DIR_HOST:-}")")"
  sed -i "s#diraddress = \"localhost\"#diraddress = \"${bareos_dir_host_repl}\"#" /etc/bareos-webui/directors.ini

  # Control file
  touch /etc/bareos-webui/bareos-config.control
fi

if [ ! -f /usr/share/bareos-webui/bareos-config.control ]; then
  tar xfvz /bareos-webui-code.tgz
  touch /usr/share/bareos-webui/bareos-config.control
fi

# Fix nginx 'client_max_body_size'
sed -i "s#client_max_body_size 1m#client_max_body_size 20m#" /etc/nginx/nginx.conf

# set php-fpm host andd port
php_fpm_host_repl="$(sed_repl "${PHP_FPM_HOST:-}")"
php_fpm_port_repl="$(sed_repl "${PHP_FPM_PORT:-}")"
sed -i "s#fastcgi_pass 127.0.0.1:9000;#fastcgi_pass ${php_fpm_host_repl}:${php_fpm_port_repl};#" /etc/nginx/http.d/bareos-webui.conf

exec "$@"
