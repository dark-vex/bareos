#!/usr/bin/env bash

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

resolve_required_password MYSQL_DB_PASSWORD "${MYSQL_DB_PASSWORD:-}" "${MYSQL_DB_PASSWORD_FILE:-}" || exit 1
MYSQL_DB_PASSWORD=$RESOLVED_PASSWORD
resolve_required_password PGSQL_DB_PASSWORD "${PGSQL_DB_PASSWORD:-}" "${PGSQL_DB_PASSWORD_FILE:-}" || exit 1
PGSQL_DB_PASSWORD=$RESOLVED_PASSWORD
resolve_required_password PGSQL_ADMIN_PASSWORD "${PGSQL_ADMIN_PASSWORD:-}" "${PGSQL_ADMIN_PASSWORD_FILE:-}" || exit 1
PGSQL_ADMIN_PASSWORD=$RESOLVED_PASSWORD

if [[ -z ${CI_TEST} ]] ; then
  # Waiting for Postgresql
  sqlup=1
  while [ "$sqlup" -ne 0 ] ; do
    echo "Waiting for postgresql..."
    pg_isready --host="${PGSQL_DB_HOST}" --port="${PGSQL_DB_PORT}"
    if [ $? -ne 0 ] ; then
      sqlup=1
      sleep 5
    else
      sqlup=0
      echo "[!] PostreSQL is alive"
    fi
  done
fi

cat << EOF > /etc/mysql.cnf
[client]
user = "${MYSQL_DB_USER}"
password = "${MYSQL_DB_PASSWORD}"
EOF

if [[ -z ${CI_TEST} ]] ; then
  # Waiting for Mysql
  sqlup=1
  while [ "$sqlup" -ne 0 ] ; do
    echo "Waiting for mysqld..."
    mysqladmin --silent -h "${MYSQL_DB_HOST}" ping
    if [ $? -ne 0 ] ; then
      sqlup=1
      sleep 5
    else
      echo "[!] MySQL is alive"
      sqlup=0
    fi
  done
fi

export PGUSER=${PGSQL_ADMIN_USER}
export PGHOST=${PGSQL_DB_HOST}
export PGPASSWORD=${PGSQL_ADMIN_PASSWORD}

if [ "${DB_INIT}" == 'true' ] ; then
  # Prepare Catalog configs to init new DB
  cat << EOF > /etc/bareos/bareos-dir.d/catalog/MyCatalog.conf
Catalog {
  Name = MyCatalog-new
  dbdriver = "postgresql"
  dbname = "$PGSQL_DB_NAME"
  dbaddress = "$PGSQL_DB_HOST"
  dbport = "$PGSQL_DB_PORT"
  dbuser = "$PGSQL_DB_USER"
  dbpassword = "$PGSQL_DB_PASSWORD"
}
EOF

  # Init Postgresql DB
  echo "Bareos PG DB init: Create Bareos database"
  /usr/lib/bareos/scripts/create_bareos_database 1>/dev/null
  echo "Bareos PG DB init: Create Bareos tables"
  /usr/lib/bareos/scripts/make_bareos_tables 1>/dev/null
  echo "Bareos PG DB init: Grant Bareos privileges"
  /usr/lib/bareos/scripts/grant_bareos_privileges 1>/dev/null
fi

# Prepare Catalog configs for migration
cat << EOF > /etc/bareos/bareos-dir.d/catalog/MyCatalog.conf
Catalog {
  Name = MyCatalog
  DB Driver = "mysql"
  DB Name = "$MYSQL_DB_NAME"
  DB Address = "$MYSQL_DB_HOST"
  DB Port = "$MYSQL_DB_PORT"
  DB User = "$MYSQL_DB_USER"
  DB PASSWORD = "$MYSQL_DB_PASSWORD"
}
Catalog {
  Name = MyCatalog-new
  DB Driver = "postgresql"
  DB Name = "$PGSQL_DB_NAME"
  DB Address = "$PGSQL_DB_HOST"
  DB Port = "$PGSQL_DB_PORT"
  DB User = "$PGSQL_DB_USER"
  DB Password = "$PGSQL_DB_PASSWORD"
}
EOF

if [ "${DB_BACKUP}" == 'true' ] ; then
  # MySQL backup
  echo "[!] Start MySQL backup"
  date=$(date +%s)
  mysqldump --defaults-extra-file=/etc/mysql.cnf --column-statistics=0  \
            --no-tablespaces --host ${MYSQL_DB_HOST} --port ${MYSQL_DB_PORT} \
            ${MYSQL_DB_NAME} > /backup/bareos-${date}.sql
  if [ $? -eq 0 ] ; then
    echo "[!] MySQL Backup success - /backup/bareos-${date}.sql"
  else
    echo "[x] MySQL Backup failed"
  fi
fi

# Start Bareos DB copy
echo "[!] Start Bareos DB copy"
su -s /bin/bash - bareos -c "bareos-dbcopy MyCatalog MyCatalog-new"

# Run Dockerfile CMD
exec "$@"
