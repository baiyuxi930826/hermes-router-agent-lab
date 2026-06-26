# Architecture

## Deployment Shape

Hermes runs inside an Ubuntu container hosted by a home soft router. The router handles the network edge and container lifecycle. The Ubuntu container provides a fuller Linux user space for Python, Node, browser tooling, and the Hermes runtime.

The production deployment uses a persistent config mount so that profile configuration, skills, scripts, and runtime state survive container restarts. Public examples in this repository use placeholders instead of the real mount paths.

## Runtime Layers

| Layer | Responsibility |
| --- | --- |
| Soft router host | Docker lifecycle, cron watchdog, local network boundary |
| Ubuntu container | Python venv, Hermes CLI, Web UI, skills, profile configs |
| Hermes gateway | Control desk and routing entry point |
| Dedicated personas | Domain-specific crypto research, strategy, and risk roles |
| Skills | Tool and workflow library used by each persona |
| External services | Model provider, market data, storage, and notification platforms |

## Persona Model

The live system was consolidated into four active personas:

| Persona | Role | Boundary |
| --- | --- | --- |
| Control desk | Status, coordination, operations, human confirmation | Routes work, does not replace specialist decisions |
| Meme hunter | Early meme discovery, narrative signals, contract and holder risk evidence | Produces `ignore`, `watchlist`, or `escalate`, never final trade approval |
| Quant strategist | Market regime, strategy choice, backtest assumptions, order drafts | Drafts plans, does not claim execution without an external receipt |
| Risk manager | Final risk gate for sizing, stop loss, leverage, liquidity, correlation | Can pass, warn, or block |

An additional WeChat profile exists as an experimental or manually started profile. It is not part of the default watchdog-managed active set.

## Health Endpoints

The live deployment exposes one local API health endpoint per active profile and a LAN-only Web UI endpoint. In a public deployment template, use placeholders:

| Component | Example |
| --- | --- |
| Control desk API | `http://127.0.0.1:${HERMES_GATEWAY_PORT}/health` |
| Meme hunter API | `http://127.0.0.1:${HERMES_MEME_PORT}/health` |
| Quant strategist API | `http://127.0.0.1:${HERMES_QUANT_PORT}/health` |
| Risk manager API | `http://127.0.0.1:${HERMES_RISK_PORT}/health` |
| Web UI | `http://${ROUTER_LAN_HOST}:${HERMES_WEB_UI_PORT}/` |

## Supervision

The production pattern uses two layers:

1. Docker restart policy keeps the Ubuntu container alive.
2. A host cron watchdog checks the container and calls an idempotent Hermes startup script.

The startup script relies on PID files and per-persona `flock` locks to avoid duplicate long-running processes. This matters for platforms where only one poller may use a bot token at a time.

