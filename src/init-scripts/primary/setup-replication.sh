#!/bin/bash

set -e # god knows why?

# echo "Setting up replication config and creating replication user..."

HBA_FILE="$PGDATA/pg_hba.conf"
CONF_FILE="$PGDATA/postgres.conf"

REPLICATOR="replicator"
REPLICATOR_PW="replicator_password"

# # Allow the replica (db02) to connect
echo "Appending config to $HBA_FILE"
echo "host replication $REPLICATOR all md5" >> "$HBA_FILE"
echo "Appended config to $HBA_FILE"

# echo "Appending config to $CONF_FILE"
# echo "" >> "$CONF_FILE"
# echo "Appended config to $CONF_FILE"

# Create replication user
echo "Creating replication user..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE ROLE $REPLICATOR WITH REPLICATION LOGIN PASSWORD '$REPLICATOR_PW';
EOSQL

echo "Created replication user"
