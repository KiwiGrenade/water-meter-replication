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

# multiple replica servers
echo "wal_level = replica" >> "$CONF_FILE"
echo "hot_standby = on" >> "$CONF_FILE"
echo "max_wal_senders = 10" >> "$CONF_FILE"
echo "max_replication_slots = 10" >> "$CONF_FILE"
echo "hot_standby_feedback = on" >> "$CONF_FILE"
echo "wal_keep_size = 1GB" >> "$CONF_FILE"

# failover
echo "wal_log_hints = on" >> "$CONF_FILE"                    # also do full page writes of non-critical updates
echo "synchronous_commit = remote_apply" >> "$CONF_FILE" # synchronization level; off, local, remote_write, remote_apply, or on
echo "synchronous_standby_names = '*'" >> "$CONF_FILE" # standby servers that provide sync rep
                                # method to choose sync standbys, number of sync standbys,
                                # and comma-separated list of application_name
                                # from standby(s); '*' = all

echo "Appending to $CONF_FILE completed"
