#!/usr/bin/env ash

set -eu

cfg_quote() {
  printf '%s' "$1" | sed -e 's/[\\"]/\\&/g'
}

sed_repl() {
  printf '%s' "$1" | sed -e 's/[\\&#]/\\&/g'
}

NL='
'

require_no_newline() {
  case "$2" in
    *"$NL"*)
      echo "docker-entrypoint: $1 must not contain a newline" >&2
      exit 1
      ;;
  esac
}

cfg_escape() {
  require_no_newline "$1" "$2"
  sed_repl "$(cfg_quote "$2")"
}

pgpass_quote() {
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/:/\\:/g'
}

pgpass_field() {
  require_no_newline "$1" "$2"
  pgpass_quote "$2"
}

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

resolve_required_password DB_PASSWORD "${DB_PASSWORD:-}" "${DB_PASSWORD_FILE:-}" || exit 1
DB_PASSWORD=$RESOLVED_PASSWORD
resolve_required_password BAREOS_SD_PASSWORD "${BAREOS_SD_PASSWORD:-}" "${BAREOS_SD_PASSWORD_FILE:-}" || exit 1
BAREOS_SD_PASSWORD=$RESOLVED_PASSWORD
resolve_required_password BAREOS_FD_PASSWORD "${BAREOS_FD_PASSWORD:-}" "${BAREOS_FD_PASSWORD_FILE:-}" || exit 1
BAREOS_FD_PASSWORD=$RESOLVED_PASSWORD
resolve_required_password BAREOS_WEBUI_PASSWORD "${BAREOS_WEBUI_PASSWORD:-}" "${BAREOS_WEBUI_PASSWORD_FILE:-}" || exit 1
BAREOS_WEBUI_PASSWORD=$RESOLVED_PASSWORD

if [ ! -f /etc/bareos/bareos-config.control ]; then
  tar xzf /bareos-dir.tgz --backup=simple --suffix=.before-control

  # Install default admin profile config
  if [ ! -f /etc/bareos/bareos-dir.d/profile/webui-admin.conf ]; then
    cp /usr/local/share/bareos/webui-admin.conf /etc/bareos/bareos-dir.d/profile/webui-admin.conf
  fi

  # Install default webUI admin config
  if [ ! -f /etc/bareos/bareos-dir.d/console/admin.conf ]; then
    cp /usr/local/share/bareos/admin.conf.example /etc/bareos/bareos-dir.d/console/admin.conf
  fi

  DB_USER_ESC=$(cfg_escape DB_USER "${DB_USER:-}")
  DB_PASSWORD_ESC=$(cfg_escape DB_PASSWORD "${DB_PASSWORD:-}")
  DB_NAME_ESC=$(cfg_escape DB_NAME "${DB_NAME:-}")
  DB_HOST_ESC=$(cfg_escape DB_HOST "${DB_HOST:-}")
  DB_PORT_ESC=$(cfg_escape DB_PORT "${DB_PORT:-}")
  SMTP_HOST_ESC=$(cfg_escape SMTP_HOST "${SMTP_HOST:-}")
  ADMIN_MAIL_ESC=$(cfg_escape ADMIN_MAIL "${ADMIN_MAIL:-}")
  BAREOS_SD_HOST_ESC=$(cfg_escape BAREOS_SD_HOST "${BAREOS_SD_HOST:-}")
  BAREOS_SD_PASSWORD_ESC=$(cfg_escape BAREOS_SD_PASSWORD "${BAREOS_SD_PASSWORD:-}")
  BAREOS_FD_HOST_ESC=$(cfg_escape BAREOS_FD_HOST "${BAREOS_FD_HOST:-}")
  BAREOS_FD_PASSWORD_ESC=$(cfg_escape BAREOS_FD_PASSWORD "${BAREOS_FD_PASSWORD:-}")
  BAREOS_WEBUI_PASSWORD_ESC=$(cfg_escape BAREOS_WEBUI_PASSWORD "${BAREOS_WEBUI_PASSWORD:-}")

  # Update bareos-director configs
  # Director / mycatalog & mail report
  sed -i "s#dbuser =.*#dbuser = \"${DB_USER_ESC}\"#" \
    /etc/bareos/bareos-dir.d/catalog/MyCatalog.conf
  sed -i "s#dbpassword =.*#dbpassword = \"${DB_PASSWORD_ESC}\"#" \
    /etc/bareos/bareos-dir.d/catalog/MyCatalog.conf
  sed -i "s#dbname =.*#dbname = \"${DB_NAME_ESC}\"\n  dbaddress = \"${DB_HOST_ESC}\"\n  dbport = \"${DB_PORT_ESC}\"#" \
    /etc/bareos/bareos-dir.d/catalog/MyCatalog.conf
  if [ -n "${SENDER_MAIL:-}" ]; then
    SENDER_MAIL_ESC=$(cfg_escape SENDER_MAIL "${SENDER_MAIL}")
    sed -i "s#<%r#<${SENDER_MAIL_ESC}#g" \
      /etc/bareos/bareos-dir.d/messages/Daemon.conf
  fi
  sed -i "s#/usr/bin/bsmtp -h localhost#/usr/bin/bsmtp -h ${SMTP_HOST_ESC}#" \
    /etc/bareos/bareos-dir.d/messages/Daemon.conf
  sed -i "s#mail = root#mail = \"${ADMIN_MAIL_ESC}\"#" \
    /etc/bareos/bareos-dir.d/messages/Daemon.conf
  if [ -n "${SENDER_MAIL:-}" ]; then
    sed -i "s#<%r#<${SENDER_MAIL_ESC}#g" \
      /etc/bareos/bareos-dir.d/messages/Standard.conf
  fi
  sed -i "s#/usr/bin/bsmtp -h localhost#/usr/bin/bsmtp -h ${SMTP_HOST_ESC}#g" \
    /etc/bareos/bareos-dir.d/messages/Standard.conf
  sed -i "s#mail = root#mail = \"${ADMIN_MAIL_ESC}\"#" \
    /etc/bareos/bareos-dir.d/messages/Standard.conf

  # Setup webhook
  if [ "${WEBHOOK_NOTIFICATION:-}" = true ]; then
    sed -i "s#/usr/bin/bsmtp -h.*#/usr/local/bin/webhook-notify %t %e %c %l %n\"#" \
      /etc/bareos/bareos-dir.d/messages/Daemon.conf
    sed -i "s#/usr/bin/bsmtp -h.*#/usr/local/bin/webhook-notify %t %e %c %l %n\"#" \
      /etc/bareos/bareos-dir.d/messages/Standard.conf
  fi

  # storage daemon
  sed -i "s#Address = .*#Address = \"${BAREOS_SD_HOST_ESC}\"#" \
    /etc/bareos/bareos-dir.d/storage/File.conf
  sed -i "s#Password = .*#Password = \"${BAREOS_SD_PASSWORD_ESC}\"#" \
    /etc/bareos/bareos-dir.d/storage/File.conf

  # client/file daemon
  sed -i "s#Address = .*#Address = \"${BAREOS_FD_HOST_ESC}\"#" \
    /etc/bareos/bareos-dir.d/client/bareos-fd.conf
  sed -i "s#Password = .*#Password = \"${BAREOS_FD_PASSWORD_ESC}\"#" \
    /etc/bareos/bareos-dir.d/client/bareos-fd.conf

  # webUI
  sed -i "s#Password = .*#Password = \"${BAREOS_WEBUI_PASSWORD_ESC}\"#" \
    /etc/bareos/bareos-dir.d/console/admin.conf

  # Bareos >=24 rejects the empty Password these bundled local-only
  # resources ship with ("Empty Password not allowed in Resource ..."); the
  # director's own bconsole.conf must carry the same value as its "myself"
  # Director resource for local `bconsole` access to keep working.
  sed -i "s#Password = .*#Password = \"${BAREOS_WEBUI_PASSWORD_ESC}\"#" \
    /etc/bareos/bareos-dir.d/director/bareos-dir.conf
  sed -i "s#Password = .*#Password = \"${BAREOS_WEBUI_PASSWORD_ESC}\"#" \
    /etc/bareos/bconsole.conf
  sed -i "s#Password = .*#Password = \"${BAREOS_WEBUI_PASSWORD_ESC}\"#" \
    /etc/bareos/bareos-dir.d/console/bareos-mon.conf


  # MyCatalog Backup
  sed -i "s#/var/lib/bareos/bareos.sql#/var/lib/bareos-director/bareos.sql#" \
    /etc/bareos/bareos-dir.d/fileset/Catalog.conf
  sed -i "s#make_catalog_backup MyCatalog#make_catalog_backup ${DB_NAME_ESC} ${DB_USER_ESC} '' ${DB_HOST_ESC}#" \
    /etc/bareos/bareos-dir.d/job/BackupCatalog.conf

  # Add pgpass file to ${DB_USER} home
  homedir=$(getent passwd "${DB_USER:-}" | cut -d: -f6)
  if [ -n "${homedir}" ]; then
    printf '%s:%s:%s:%s:%s\n' \
      "$(pgpass_field DB_HOST "${DB_HOST:-}")" \
      "$(pgpass_field DB_PORT "${DB_PORT:-}")" \
      "$(pgpass_field DB_NAME "${DB_NAME:-}")" \
      "$(pgpass_field DB_USER "${DB_USER:-}")" \
      "$(pgpass_field DB_PASSWORD "${DB_PASSWORD:-}")" \
      > "${homedir}/.pgpass"
    chmod 600 "${homedir}/.pgpass"
    chown "${DB_USER:-}" "${homedir}/.pgpass"
  fi

  # Control file
  touch /etc/bareos/bareos-config.control
fi

if [ -z "${CI_TEST:-}" ]; then
  # Waiting Postgresql is up
  until pg_isready --host="${DB_HOST:-}" --port="${DB_PORT:-}" --user="${DB_ADMIN_USER:-}" >/dev/null 2>&1; do
    echo "Waiting for postgresql..."
    sleep 5
  done
  echo "...postgresql is alive"
fi

export PGUSER="${DB_ADMIN_USER:-}"
export PGHOST="${DB_HOST:-}"
: "${DB_INIT:=false}"
: "${DB_UPDATE:=false}"

if [ -n "${DB_ADMIN_PASSWORD_FILE:-}" ] || [ -n "${DB_ADMIN_PASSWORD:-}" ] \
   || [ "$DB_INIT" = true ] || [ "$DB_UPDATE" = true ]; then
  resolve_required_password DB_ADMIN_PASSWORD "${DB_ADMIN_PASSWORD:-}" "${DB_ADMIN_PASSWORD_FILE:-}" || exit 1
  DB_ADMIN_PASSWORD=$RESOLVED_PASSWORD
fi
export PGPASSWORD="${DB_ADMIN_PASSWORD:-}"

if [ ! -f /etc/bareos/bareos-db.control ] && [ "${DB_INIT}" = 'true' ]; then
  # Init Postgres DB
  echo "Bareos DB init"
  echo "Bareos DB init: Create/alter user ${DB_USER:-}"
  psql -v ON_ERROR_STOP=1 -v db_user="${DB_USER:-}" -v db_password="${DB_PASSWORD:-}" <<'EOSQL'
SELECT NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = :'db_user') AS create_user \gset
\if :create_user
CREATE USER :"db_user" WITH CREATEDB CREATEROLE LOGIN;
\endif
ALTER USER :"db_user" PASSWORD :'db_password';
EOSQL
  /etc/bareos/scripts/create_bareos_database 2>/dev/null || true
  /etc/bareos/scripts/make_bareos_tables  2>/dev/null || true
  /etc/bareos/scripts/grant_bareos_privileges  2>/dev/null || true
  # Control file
  touch /etc/bareos/bareos-db.control
fi

if [ "${DB_UPDATE}" = 'true' ]; then
  # Try Postgres upgrade
  echo "Bareoos DB update"
  echo "Bareoos DB update: Update tables"
  /etc/bareos/scripts/update_bareos_tables  2>/dev/null || true
  echo "Bareoos DB update: Grant privileges"
  /etc/bareos/scripts/grant_bareos_privileges  2>/dev/null || true
fi

# Fix permissions
find /etc/bareos ! -user bareos -exec chown bareos {} \;
chown -R bareos:bareos /var/lib/bareos /var/log/bareos

# Run Dockerfile CMD
exec "$@"
