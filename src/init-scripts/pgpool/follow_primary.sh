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
BACKEND_CONTAINERS="${BACKEND_CONTAINERS:-}"

FAILOVER_DB_USER="${FAILOVER_DB_USER:-failover}"
FAILOVER_DB_PASS="${FAILOVER_DB_PASS:-failover_pass}"

REPL_USER="${REPL_USER:-replicator}"
REPL_PASS="${REPL_PASS:-replicator_password}"
REPL_PORT="${REPL_PORT:-5432}"

if [ -z "$BACKEND_CONTAINERS" ]; then
  echo "follow_primary.sh: BACKEND_CONTAINERS is empty"
  exit 1
fi

dex() {
  local ctr="$1"; shift
  docker exec -u "$POSTGRES_USER_IN_NODE" "$ctr" sh -lc "$*"
}

echo "follow_primary.sh: new_primary=$NEW_MAIN_NODE_HOST backends='$BACKEND_CONTAINERS'"

for ctr in $BACKEND_CONTAINERS; do
  [ "$ctr" = "$NEW_MAIN_NODE_HOST" ] && continue

  if ! docker ps --format '{{.Names}}' | grep -qx "$ctr"; then
    echo "follow_primary.sh: $ctr not running -> skip"
    continue
  fi

  is_recovery="$(dex "$ctr" "PGPASSWORD='$FAILOVER_DB_PASS' psql -U '$FAILOVER_DB_USER' -d postgres -Atc \"SELECT pg_is_in_recovery();\" 2>/dev/null || echo ''")"
  if [ "$is_recovery" != "t" ]; then
    echo "follow_primary.sh: $ctr not standby -> skip"
    continue
  fi

  echo "follow_primary.sh: re-point $ctr -> $NEW_MAIN_NODE_HOST"

  # ALTER SYSTEM osobno (żeby nie wpaść w transaction block)
  dex "$ctr" "PGPASSWORD='$FAILOVER_DB_PASS' psql -U '$FAILOVER_DB_USER' -d postgres -v ON_ERROR_STOP=1 -c \
\"ALTER SYSTEM SET primary_conninfo TO 'host=${NEW_MAIN_NODE_HOST} port=${REPL_PORT} user=${REPL_USER} password=${REPL_PASS} application_name=${ctr}'\""

  # reload osobno
  dex "$ctr" "PGPASSWORD='$FAILOVER_DB_PASS' psql -U '$FAILOVER_DB_USER' -d postgres -v ON_ERROR_STOP=1 -c \
\"SELECT pg_reload_conf();\""

  # Najpewniejsze: restart standby, żeby walreceiver od razu złapał nowe conninfo
  # docker restart "$ctr" >/dev/null

# dex "$ctr" "PGPASSWORD='$FAILOVER_DB_PASS' psql -U '$FAILOVER_DB_USER' -d postgres -Atc \
# \"SELECT pg_terminate_backend(pid)
#  FROM pg_stat_activity
#  WHERE backend_type = 'walreceiver';\""


done

echo "follow_primary.sh: done"
exit 0

