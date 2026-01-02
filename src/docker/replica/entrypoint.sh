#!/usr/bin/env bash
set -euo pipefail

PRIMARY_HOST="${PRIMARY_HOST:-postgres-primary}"
PRIMARY_PORT="${PRIMARY_PORT:-5432}"
#
echo "[replica] PGDATA=${PGDATA} primary=${PRIMARY_HOST}:${PRIMARY_PORT} user=${PGUSER}"

# Init only if empty
if [[ ! -s "${PGDATA}/PG_VERSION" ]]; then
    echo "[replica] empty PGDATA -> pg_basebackup"

    rm -rf "${PGDATA:?}/"*

    gosu postgres pg_basebackup \
        -D "${PGDATA}" \
        -R \
        -X stream \
        --checkpoint=fast \
        -h "${PRIMARY_HOST}" -p "${PRIMARY_PORT}" -U "${PGUSER}"

    chown -R postgres:postgres "${PGDATA}"
    echo "[replica] basebackup done."
else
    echo "[replica] existing PGDATA -> skip basebackup."
fi 
echo "[replica] start postgres"
exec docker-entrypoint.sh postgres
