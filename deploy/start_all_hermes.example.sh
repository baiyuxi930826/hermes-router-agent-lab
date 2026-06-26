#!/usr/bin/env bash
set -u

# Idempotently start or stop the active Hermes persona set.
# This is a sanitized public version of the live router deployment script.

export HOME="${HOME:-/config}"
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:${PATH:-}"

if [[ -n "${HERMES_PROXY_URL:-}" ]]; then
  export HTTP_PROXY="$HERMES_PROXY_URL"
  export HTTPS_PROXY="$HERMES_PROXY_URL"
  export ALL_PROXY="$HERMES_PROXY_URL"
  export http_proxy="$HERMES_PROXY_URL"
  export https_proxy="$HERMES_PROXY_URL"
  export all_proxy="$HERMES_PROXY_URL"
fi

export NO_PROXY="${HERMES_NO_PROXY:-localhost,127.0.0.1,::1,172.17.0.0/16,192.168.0.0/16,10.0.0.0/8}"
export no_proxy="$NO_PROXY"

HERMES="${HERMES_BIN:-/config/.local/bin/hermes}"
VENV_PY="${HERMES_VENV_PY:-/config/.hermes/hermes-agent/venv/bin/python3}"
LOG_DIR="${HERMES_LOG_DIR:-/config/.hermes/logs}"
PID_DIR="${HERMES_PID_DIR:-/tmp}"

PERSONAS=(meme-hunter quant-strategist risk-manager)

mkdir -p "$LOG_DIR"

pid_file_path() {
  echo "${PID_DIR}/hermes-${1}.pid"
}

cmdline_matches_slug() {
  local pid="$1" slug="$2" cmdline
  [[ -r "/proc/$pid/cmdline" ]] || return 1
  cmdline="$(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null)"
  case "$cmdline" in
    *"$VENV_PY $HERMES"*) ;;
    *) return 1 ;;
  esac
  if [[ "$slug" == "gateway" ]]; then
    case "$cmdline" in
      *" -p "*) return 1 ;;
      *"hermes gateway run"*) return 0 ;;
      *) return 1 ;;
    esac
  else
    case "$cmdline" in
      *"-p $slug gateway run"*) return 0 ;;
      *) return 1 ;;
    esac
  fi
}

pid_for() {
  local slug="$1" pf pid pattern found
  pf="$(pid_file_path "$slug")"
  if [[ -f "$pf" ]]; then
    pid="$(cat "$pf" 2>/dev/null)"
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null && cmdline_matches_slug "$pid" "$slug"; then
      echo "$pid"
      return 0
    fi
    rm -f "$pf"
  fi

  if [[ "$slug" == "gateway" ]]; then
    pattern="$VENV_PY $HERMES gateway run"
  else
    pattern="$VENV_PY $HERMES -p $slug gateway run"
  fi

  found="$(ps -eo pid=,comm=,args= 2>/dev/null | awk -v pat="$pattern" '$2 ~ /^python/ && index($0, pat) { print $1; exit }')"
  if [[ -n "$found" ]]; then
    echo "$found" > "$pf" 2>/dev/null
    echo "$found"
  fi
}

status_one() {
  local slug="$1" pid rss_kb
  pid="$(pid_for "$slug")"
  if [[ -n "$pid" ]]; then
    rss_kb="$(awk '/VmRSS/ {print $2}' "/proc/$pid/status" 2>/dev/null || echo 0)"
    printf "  %-20s running  pid=%-7s rss=%sMB\n" "$slug" "$pid" "$((rss_kb / 1024))"
  else
    printf "  %-20s DOWN\n" "$slug"
  fi
}

start_one() {
  local slug="$1" lock_path="${PID_DIR}/hermes-${slug}.start.lock"
  (
    if ! flock -n 9; then
      printf "  %-20s [skip] start lock held by another run\n" "$slug"
      exit 0
    fi
    if [[ -n "$(pid_for "$slug")" ]]; then
      printf "  %-20s [skip] already running\n" "$slug"
      exit 0
    fi

    local logfile pf pid
    pf="$(pid_file_path "$slug")"
    if [[ "$slug" == "gateway" ]]; then
      logfile="$LOG_DIR/hermes-root.log"
      nohup "$VENV_PY" "$HERMES" gateway run 9>&- > "$logfile" 2>&1 &
    else
      logfile="$LOG_DIR/hermes-$slug.log"
      nohup "$VENV_PY" "$HERMES" -p "$slug" gateway run 9>&- > "$logfile" 2>&1 &
    fi
    pid=$!
    echo "$pid" > "$pf"
    printf "  %-20s [start] pid=%s log=%s\n" "$slug" "$pid" "$logfile"
    sleep 30
  ) 9>"$lock_path"
}

stop_one() {
  local slug="$1" pid pf
  pf="$(pid_file_path "$slug")"
  pid="$(pid_for "$slug")"
  if [[ -n "$pid" ]]; then
    kill "$pid" 2>/dev/null
    rm -f "$pf"
    printf "  %-20s [kill] pid=%s\n" "$slug" "$pid"
  else
    rm -f "$pf"
    printf "  %-20s [skip] not running\n" "$slug"
  fi
}

cmd_status() {
  echo "== Hermes active persona status =="
  status_one gateway
  for p in "${PERSONAS[@]}"; do
    status_one "$p"
  done
}

cmd_start() {
  echo "== Starting Hermes personas =="
  start_one gateway
  for p in "${PERSONAS[@]}"; do
    start_one "$p"
  done
}

cmd_stop() {
  echo "== Stopping Hermes active personas =="
  for p in "${PERSONAS[@]}"; do
    stop_one "$p"
  done
  stop_one gateway
}

case "${1:-start}" in
  --status|-s|status) cmd_status ;;
  --stop|stop) cmd_stop ;;
  --start|start|"") cmd_start ;;
  *) echo "Usage: $0 [--start|--status|--stop]" >&2; exit 2 ;;
esac

