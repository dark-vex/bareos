#!/usr/bin/env ash
set -eu
#set -x

BAREOS_DIR_HOST="${BAREOS_DIR_HOST:-}"

if [ -n "${JWT_SECRET_FILE:-}" ]; then
  if [ ! -r "$JWT_SECRET_FILE" ]; then
    echo "JWT_SECRET_FILE=${JWT_SECRET_FILE} is not readable" >&2
    exit 1
  fi
  secret=$(cat "$JWT_SECRET_FILE")
elif [ -n "${JWT_SECRET:-}" ]; then
  secret="$JWT_SECRET"
else
  secret=$(python3 -c "import secrets; print(secrets.token_urlsafe(30))")
fi

umask 077

cat <<EOF > /home/bareos/api.ini
[Director]
Name=${BAREOS_DIR_HOST}
Address=${BAREOS_DIR_HOST}
Port=9101

[JWT]
secret_key = ${secret}
algorithm = HS256
access_token_expire_minutes = 30
EOF

chmod 600 /home/bareos/api.ini

exec "$@"
