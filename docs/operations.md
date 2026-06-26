# Operations

## Daily Checks

Use SSH to the router and execute commands inside the Ubuntu container:

```bash
ssh "${ROUTER_ALIAS:-router}" "docker ps --format '{{.Names}} {{.Status}}'"
ssh "${ROUTER_ALIAS:-router}" "docker exec ${HERMES_CONTAINER:-ubuntu2} bash /config/.hermes/scripts/start_all_hermes.sh --status"
```

Check local health endpoints from inside the container:

```bash
ssh "${ROUTER_ALIAS:-router}" "docker exec ${HERMES_CONTAINER:-ubuntu2} curl -fsS http://127.0.0.1:${HERMES_GATEWAY_PORT:-8642}/health"
```

## Start Or Repair

```bash
ssh "${ROUTER_ALIAS:-router}" "docker exec ${HERMES_CONTAINER:-ubuntu2} bash /config/.hermes/scripts/start_all_hermes.sh --start"
```

The launcher is idempotent. Running it repeatedly should skip personas that are already alive.

## Stop Active Personas

```bash
ssh "${ROUTER_ALIAS:-router}" "docker exec ${HERMES_CONTAINER:-ubuntu2} bash /config/.hermes/scripts/start_all_hermes.sh --stop"
```

## Watchdog Pattern

Install a host-level cron entry similar to:

```cron
*/5 * * * * /root/ensure-ubuntu2-hermes.sh >> /tmp/ensure-ubuntu2-hermes.cron.log 2>&1
```

Five minutes is a conservative interval. It gives network clients and bot polling libraries time to recover from short disconnects before the watchdog intervenes.

## Upgrade Notes

The live deployment observed an upstream update warning. Treat upgrades as a separate maintenance window:

1. Snapshot the persistent Hermes config directory.
2. Check local source modifications with `git status`.
3. Pull or update the upstream Hermes source.
4. Reinstall dependencies in the venv.
5. Start one profile first and run health checks.
6. Start the full active set only after the canary profile is healthy.

## Failure Modes

| Symptom | Likely area | First check |
| --- | --- | --- |
| Web UI loads but profile cannot respond | Gateway or model provider | Container logs and profile health endpoint |
| Duplicate bot polling conflict | Watchdog race or stale process | PID files and `flock` lock behavior |
| Health endpoint down | Profile process | `start_all_hermes.sh --status` |
| Container restarted but personas missing | Cron, HOME, or persistent path | `HOME=/config` and startup script location |
| Model calls fail | Provider URL, API key, proxy path | Redacted env and provider health checks |

