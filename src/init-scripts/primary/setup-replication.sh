#!/bin/bash

set -e # god knows why?

# echo "Setting up replication config and creating replication user..."

HBA_FILE="$PGDATA/pg_hba.conf"

REPLICATOR1="replicator1"
REPLICATOR1_PW="replicator1_password"

# # Allow the replica (db02) to connect
echo "Appending config to $HBA_FILE"
echo "host replication $REPLICATOR1 all md5" >> "$HBA_FILE"
echo "Appended config to $HBA_FILE"

# Create replication user
echo "Creating replication user..."
psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
  CREATE ROLE $REPLICATOR1 WITH REPLICATION LOGIN PASSWORD '$REPLICATOR1_PW';
EOSQL

echo "Created replication user"
