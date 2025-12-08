#!/bin/bash

set -e

POSTGRESQL_DIR="/var/lib/postgresql/"

echo "Replica entrypoint – PGDATA=${PGDATA}"

# Jeśli nie ma pliku PG_VERSION → brak zainicjalizowanej bazy
if [ ! -s "${PGDATA}/PG_VERSION" ]; then
  echo "No existing database found in ${PGDATA}. Initializing replica via pg_basebackup..."

  rm -rf "${PGDATA:?}/"*

  # Bazujemy na zmiennych środowiskowych PGUSER/PGPASSWORD ustawionych w docker-compose
  pg_basebackup \
    -D "${PGDATA}" \
    -R \
    --host=postgres-primary \
    --checkpoint=fast \
    --slot=replicator_slot \
    -C

  # Ustaw właściciela
  echo "Setting ${POSTGRESQL_DIR} ownership rights."
  chown -R postgres:postgres ${POSTGRESQL_DIR} 

  echo "Replica basebackup completed."

else
  echo "Existing database detected in ${PGDATA}. Skipping pg_basebackup."
fi

echo "Starting postgres replica server..."

exec docker-entrypoint.sh postgres
