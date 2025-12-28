#!/bin/bash
set -e

HBA_FILE="$PGDATA/pg_hba.conf"
CONF_FILE="$PGDATA/postgresql.conf"
REPLICATOR="replicator"


echo "Appending config to $HBA_FILE"

# Add rule for replication connection as user $REPLICATOR from any address
echo "host replication $REPLICATOR 0.0.0.0/0 scram-sha-256" >> "$HBA_FILE"
echo "host replication $REPLICATOR ::/0       scram-sha-256" >> "$HBA_FILE"

echo "Appending to $HBA_FILE completed"


echo "Appending config to $CONF_FILE"

echo "wal_level = replica" >> "$CONF_FILE"
echo "max_wal_senders = 10" >> "$CONF_FILE"
echo "wal_keep_size = 1GB" >> "$CONF_FILE"

echo "Appending to $CONF_FILE completed"
