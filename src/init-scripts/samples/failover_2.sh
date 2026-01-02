#!/bin/sh
set -eu

FAILED_NODE_ID="$1"
NEW_PRIMARY_HOST="$2"
OLD_PRIMARY_NODE_ID="$3"
OLD_PRIMARY_HOST="$4"

# dane do logowania na replice
PGPORT="${PGPORT:-5432}"
PGUSER="${PGPOOL_FAILOVER_USER:-failover}"
PGPASSWORD="${PGPOOL_FAILOVER_PASSWORD:-failover_pass}"
export PGPASSWORD

echo "[failover] failed_node_id=$FAILED_NODE_ID old_primary=$OLD_PRIMARY_HOST($OLD_PRIMARY_NODE_ID) candidate=$NEW_PRIMARY_HOST"

# 1) sprawdź czy kandydat żyje i jest w recovery (czyli replika)
psql -h "$NEW_PRIMARY_HOST" -p "$PGPORT" -U "$PGUSER" -d postgres -v ON_ERROR_STOP=1 -Atc "SELECT pg_is_in_recovery();" | grep -q 't' \
  || { echo "[failover] candidate is not in recovery or not reachable"; exit 1; }

# 2) promuj
psql -h "$NEW_PRIMARY_HOST" -p "$PGPORT" -U "$PGUSER" -d postgres -v ON_ERROR_STOP=1 -Atc "SELECT pg_promote(wait_seconds => 60);"

# 3) sanity-check: po promocji powinno być 'f'
psql -h "$NEW_PRIMARY_HOST" -p "$PGPORT" -U "$PGUSER" -d postgres -v ON_ERROR_STOP=1 -Atc "SELECT pg_is_in_recovery();" | grep -q 'f' \
  || { echo "[failover] promote did not finish"; exit 1; }

echo "[failover] promote OK on $NEW_PRIMARY_HOST"
exit 0

