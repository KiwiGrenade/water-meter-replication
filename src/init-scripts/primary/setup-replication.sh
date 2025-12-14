#!/bin/bash
set -e

HBA_FILE="$PGDATA/pg_hba.conf"
REPLICATOR="replicator"

echo "Appending config to $HBA_FILE"

# Replication connections from anywhere (IPv4 + IPv6)
echo "host replication $REPLICATOR 0.0.0.0/0 scram-sha-256" >> "$HBA_FILE"
echo "host replication $REPLICATOR ::/0       scram-sha-256" >> "$HBA_FILE"

# Regular connections from anywhere (IPv4 + IPv6) – needed e.g. for pgpool health/sr checks
echo "host all         $REPLICATOR 0.0.0.0/0 scram-sha-256" >> "$HBA_FILE"
echo "host all         $REPLICATOR ::/0       scram-sha-256" >> "$HBA_FILE"

echo "Created replication user"

