# Security And Public Release Policy

## What Stays Private

Never commit these files or values:

- `.env`, `.env.*`, private config overrides, and backup env files.
- Model API keys, provider tokens, proxy credentials, webhook secrets, and exchange keys.
- Telegram bot tokens, Telegram session data, WeChat tokens, cookies, and browser profiles.
- SQLite state stores, WAL files, response stores, chat logs, memory stores, and caches.
- Real LAN addresses, DDNS domains, tunnel endpoints, and public bypass URLs.
- Trading account state, balances, positions, wallet addresses, and private strategy logs.

## What Can Be Public

Safe public material:

- High-level architecture.
- Sanitized examples of startup, watchdog, and health-check scripts.
- Placeholder environment files.
- Persona responsibility summaries with handles and secrets removed.
- Operational runbooks that use generic environment variables.
- A redacted inventory script.

## Redaction Rules

The inventory collector redacts lines containing:

```text
api_key, token, secret, password, passwd, session, cookie,
authorization, bearer, chat_id, bot_token, telegram, weixin
```

It also avoids known runtime directories such as caches, browser profiles, logs, database files, and session stores.

## Pre-Push Checklist

Before publishing:

```bash
git status --short
git diff --cached
git grep -n -i "api_key\\|token\\|secret\\|password\\|passwd\\|session\\|cookie\\|authorization\\|bearer"
```

Recommended optional scan:

```bash
gitleaks detect --source . --no-git
```

If a secret is ever committed, rotate it immediately. Removing it from the latest commit is not enough if it was pushed to a remote.

