#!/usr/bin/env bash
set -euo pipefail

ROUTER_ALIAS="${ROUTER_ALIAS:-router}"
CONTAINER="${HERMES_CONTAINER:-ubuntu2}"

ssh "$ROUTER_ALIAS" "docker exec -i $CONTAINER bash -s" <<'REMOTE'
set -euo pipefail

redact() {
  sed -E \
    -e 's#(api[_-]?key|token|secret|password|passwd|session|cookie|authorization|bearer|chat_id|bot_token|telegram|weixin)([[:space:]]*[:=][[:space:]]*)[^[:space:]"'\'']+#\1\2<REDACTED>#Ig' \
    -e 's#(https?://)[^/@[:space:]]+:[^/@[:space:]]+@#\1<REDACTED>@#Ig' \
    -e 's#(postgres|redis)://[^[:space:]"'\'']+#\1://<REDACTED>#Ig'
}

section() {
  printf '\n== %s ==\n' "$1"
}

section meta
printf 'date: '; date '+%F %T %Z' 2>/dev/null || true
printf 'python: '; /config/.hermes/hermes-agent/venv/bin/python3 --version 2>/dev/null || true
printf 'hermes: '; /config/.hermes/hermes-agent/venv/bin/python3 /config/.local/bin/hermes --version 2>/dev/null | head -1 || true

section health
for p in 8642 8643 8646 8647 8648 8670; do
  printf '%s ' "$p"
  curl -fsS --max-time 3 "http://127.0.0.1:$p/health" 2>/dev/null | redact \
    || curl -fsSI --max-time 3 "http://127.0.0.1:$p/" 2>/dev/null | head -1 \
    || true
  echo
done

section top_dirs
find /config/.hermes -maxdepth 2 \
  \( -path '*/venv' -o -path '*/tmp' -o -path '*/cache' -o -path '*/logs' -o -path '*/sessions' -o -path '*/node_modules' -o -path '*/chrome-*' -o -path '*telegram*' -o -path '*_backups*' \) -prune -o \
  -printf '%y %p\n' 2>/dev/null \
  | sed 's#/config/.hermes#.hermes#' \
  | sort \
  | redact

section profile_files
find /config/.hermes/profiles -maxdepth 3 -type f \
  \( -name SOUL.md -o -name config.yaml \) \
  -printf '%p\n' 2>/dev/null \
  | sort \
  | sed 's#/config/.hermes#.hermes#' \
  | redact

section scripts
find /config/.hermes/scripts -maxdepth 2 -type f \
  -printf '%p\n' 2>/dev/null \
  | sort \
  | sed 's#/config/.hermes#.hermes#' \
  | redact
REMOTE

