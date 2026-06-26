#!/bin/sh
set -u

LOCKDIR="${HERMES_WATCHDOG_LOCKDIR:-/tmp/ensure-hermes.lock}"
LOG="${HERMES_WATCHDOG_LOG:-/tmp/ensure-hermes.log}"
CONTAINER="${HERMES_CONTAINER:-ubuntu2}"
START_SCRIPT="${HERMES_START_SCRIPT:-/config/.hermes/scripts/start_all_hermes.sh}"
WEBUI_PORT="${HERMES_WEB_UI_PORT:-8670}"

if ! mkdir "$LOCKDIR" 2>/dev/null; then
  exit 0
fi
trap 'rmdir "$LOCKDIR" 2>/dev/null || true' EXIT

stamp() { date '+%F %T %Z'; }
log() { echo "[$(stamp)] $*" >> "$LOG"; }

wait_for_docker() {
  i=0
  while [ "$i" -lt 60 ]; do
    if docker info >/dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
    sleep 2
  done
  log "docker daemon not ready after 120s"
  return 1
}

wait_for_container_exec() {
  i=0
  while [ "$i" -lt 60 ]; do
    if docker exec "$CONTAINER" true >/dev/null 2>&1; then
      return 0
    fi
    i=$((i + 1))
    sleep 2
  done
  log "$CONTAINER exec not ready after 120s"
  return 1
}

wait_for_docker || exit 1

if ! docker inspect "$CONTAINER" >/dev/null 2>&1; then
  log "$CONTAINER container missing"
  exit 1
fi

if ! docker ps --format '{{.Names}}' | grep -qx "$CONTAINER"; then
  log "$CONTAINER is not running; starting"
  docker start "$CONTAINER" >> "$LOG" 2>&1 || exit 1
  sleep 15
fi

wait_for_container_exec || exit 1

if docker exec "$CONTAINER" test -x "$START_SCRIPT" >/dev/null 2>&1; then
  docker exec "$CONTAINER" bash "$START_SCRIPT" --start >> "$LOG" 2>&1
else
  log "$START_SCRIPT missing or not executable"
fi

docker exec "$CONTAINER" sh -c "curl -fsS --max-time 5 http://127.0.0.1:${WEBUI_PORT}/ >/dev/null 2>&1" \
  >> "$LOG" 2>&1 || log "web UI health check failed"

