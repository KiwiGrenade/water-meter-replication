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

REPL_USER="${REPL_USER:-replicator}"
REPL_PASS="${REPL_PASS:-replicator_password}"
REPL_PORT="${REPL_PORT:-5432}"

# W follow_primary pgpool odpala skrypt per-node.
# W tym wywołaniu "FAILED_NODE_HOST" jest hostem noda, którego dotyczy akcja (czyli "ten jeden node").
CTR="$FAILED_NODE_HOST"

dex() {
  local ctr="$1"; shift
  docker exec -u "$POSTGRES_USER_IN_NODE" "$ctr" sh -lc "$*"
}

echo "follow_primary.sh: target_node=$CTR new_primary=$NEW_MAIN_NODE_HOST"

# jeżeli target to nowy primary, to nic nie rób
if [ "$CTR" = "$NEW_MAIN_NODE_HOST" ]; then
  echo "follow_primary.sh: $CTR is the new primary -> skip"
  echo "follow_primary.sh: done"
  exit 0
fi

# jeżeli kontener nie działa -> skip
if ! docker ps --format '{{.Names}}' | grep -qx "$CTR"; then
  echo "follow_primary.sh: $CTR not running -> skip"
  echo "follow_primary.sh: done"
  exit 0
fi

# jeżeli nie jest standby -> skip
is_recovery="$(dex "$CTR" "PGPASSWORD='$FAILOVER_DB_PASS' psql -U '$FAILOVER_DB_USER' -d postgres -Atc \"SELECT pg_is_in_recovery();\" 2>/dev/null || echo ''")"
if [ "$is_recovery" != "t" ]; then
  echo "follow_primary.sh: $CTR not standby -> skip"
  echo "follow_primary.sh: done"
  exit 0
fi

echo "follow_primary.sh: re-point $CTR -> $NEW_MAIN_NODE_HOST"

# ALTER SYSTEM osobno (żeby nie wpaść w transaction block)
dex "$CTR" "PGPASSWORD='$FAILOVER_DB_PASS' psql -U '$FAILOVER_DB_USER' -d postgres -v ON_ERROR_STOP=1 -c \
\"ALTER SYSTEM SET primary_conninfo TO 'host=${NEW_MAIN_NODE_HOST} port=${REPL_PORT} user=${REPL_USER} password=${REPL_PASS} application_name=${CTR}'\""

# reload osobno
dex "$CTR" "PGPASSWORD='$FAILOVER_DB_PASS' psql -U '$FAILOVER_DB_USER' -d postgres -v ON_ERROR_STOP=1 -c \
\"SELECT pg_reload_conf();\""

# Najpewniejsze: restart standby, żeby walreceiver od razu złapał nowe conninfo
# docker restart "$CTR" >/dev/null

# dex "$CTR" "PGPASSWORD='$FAILOVER_DB_PASS' psql -U '$FAILOVER_DB_USER' -d postgres -Atc \
# \"SELECT pg_terminate_backend(pid)
#  FROM pg_stat_activity
#  WHERE backend_type = 'walreceiver';\""

echo "follow_primary.sh: done"
exit 0

