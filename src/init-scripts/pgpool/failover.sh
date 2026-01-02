#!/bin/bash
set -euo pipefail
set -o xtrace

FAILED_NODE_ID="$1"
FAILED_NODE_HOST="$2"
FAILED_NODE_PORT="$3"
FAILED_NODE_PGDATA="$4"
NEW_MAIN_NODE_ID="$5"
NEW_MAIN_NODE_HOST="$6"
OLD_MAIN_NODE_ID="$7"
OLD_PRIMARY_NODE_ID="$8"
NEW_MAIN_NODE_PORT="$9"
NEW_MAIN_NODE_PGDATA="${10}"
OLD_PRIMARY_NODE_HOST="${11}"
OLD_PRIMARY_NODE_PORT="${12}"

POSTGRES_USER_IN_NODE="${POSTGRES_USER_IN_NODE:-postgres}"
FAILOVER_DB_USER="${FAILOVER_DB_USER:-failover}"
FAILOVER_DB_PASS="${FAILOVER_DB_PASS:-failover_pass}"

REPL_SLOT_NAME="${FAILED_NODE_HOST//[-.]/_}"

dex() {
  local ctr="$1"; shift
  docker exec -u "$POSTGRES_USER_IN_NODE" "$ctr" sh -lc "$*"
}

echo "failover.sh: start failed_node_id=$FAILED_NODE_ID failed_host=$FAILED_NODE_HOST old_primary_node_id=$OLD_PRIMARY_NODE_ID new_main_node_id=$NEW_MAIN_NODE_ID new_main_host=$NEW_MAIN_NODE_HOST"

if [ "$NEW_MAIN_NODE_ID" -lt 0 ]; then
  echo "failover.sh: All nodes are down. Skipping failover."
  exit 0
fi

# Jeśli padła replika (nie primary) -> skasuj slot na primary i wyjdź
if [ "$OLD_PRIMARY_NODE_ID" != "-1" ] && [ "$FAILED_NODE_ID" != "$OLD_PRIMARY_NODE_ID" ]; then
  echo "failover.sh: standby down -> drop slot $REPL_SLOT_NAME on $OLD_PRIMARY_NODE_HOST"
  set +e
  dex "$OLD_PRIMARY_NODE_HOST" "PGPASSWORD='$FAILOVER_DB_PASS' psql -U '$FAILOVER_DB_USER' -d postgres -v ON_ERROR_STOP=1 -Atc \"SELECT pg_drop_replication_slot('${REPL_SLOT_NAME}');\" >/dev/null"
  set -e
  echo "failover.sh: end (standby down)"
  exit 0
fi

echo "failover.sh: promote $NEW_MAIN_NODE_HOST as db user $FAILOVER_DB_USER"
dex "$NEW_MAIN_NODE_HOST" "PGPASSWORD='$FAILOVER_DB_PASS' psql -U '$FAILOVER_DB_USER' -d postgres -v ON_ERROR_STOP=1 -Atc \"SELECT pg_promote(wait => true);\""
echo "failover.sh: end (promoted $NEW_MAIN_NODE_HOST)"
exit 0

