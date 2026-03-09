---
name: openclaw-cli-proxy-setup
description: Install and configure CLIProxyAPI on macOS so OpenClaw can use Codex through a local OpenAI-compatible proxy with multi-account rotation. Use when the user asks to set up, reinstall, migrate, or repair a local CLIProxyAPI + OpenClaw integration, especially for Codex OAuth accounts, launchd autostart, management UI access, or OpenClaw model/provider wiring.
---

# OpenClaw CLI Proxy Setup

Install CLIProxyAPI from the official GitHub release, run it as a local `launchd` service, wire OpenClaw to the local `/v1` endpoint, and verify the setup without breaking the user's current default model before accounts are added.

Prefer the safe path:
- add a new OpenClaw provider
- keep the current OpenClaw primary model unchanged
- create a separate candidate config if the user later wants CLIProxyAPI to become the default

Do not follow Linux/Docker tutorials verbatim on macOS. Use the official macOS binary release unless the user explicitly asks for another installation method.

## Workflow

1. Inspect the machine.
2. Fetch the latest official CLIProxyAPI release metadata from GitHub.
3. Download the correct `darwin_arm64` or `darwin_amd64` tarball.
4. Create a local-only config and install directory.
5. Register a `launchd` agent.
6. Add a non-breaking OpenClaw provider that points at `http://127.0.0.1:8317/v1`.
7. Verify `launchd`, port binding, `/v1/models`, and the management page.
8. Hand the user the management URL and explain that Codex accounts still need to be added.

## Inspect The Machine

Check these first:
- `uname -sm` to detect `Darwin arm64` vs `Darwin x86_64`
- `which gh`, `which jq`, `openssl version`
- `ls -la ~/.openclaw`
- `test -f ~/.openclaw/openclaw.json`
- `ls -la ~/Library/LaunchAgents`

If `gh` is missing, fall back to `curl` with the GitHub release URL. If `jq` is missing, use structured shell or another safe editor, but prefer `jq` for JSON changes.

## Install CLIProxyAPI

Use the official release channel, not an unverified mirror.

1. Query the latest release metadata:

```bash
gh release view --repo router-for-me/CLIProxyAPI --json tagName,assets
```

2. Select the correct asset:
- `CLIProxyAPI_<version>_darwin_arm64.tar.gz` for Apple Silicon
- `CLIProxyAPI_<version>_darwin_amd64.tar.gz` for Intel Macs

3. Create an install root. Prefer a stable user-writable path such as:
- `~/Documents/Playground/cli-proxy-api-local`
- or a workspace path the user explicitly asked for

4. Create these directories under the install root:
- `bin`
- `config`
- `logs`
- `auth-dir`
- `launchd`

5. Download and extract the tarball into `bin`.

6. Generate two secrets with `openssl rand -hex`:
- one management secret for the management API/UI
- one client API key used by OpenClaw

7. Write `config/config.yaml` with these defaults unless the user requests otherwise:

```yaml
host: "127.0.0.1"
port: 8317
remote-management:
  allow-remote: false
  secret-key: "<generated-management-secret>"
  disable-control-panel: false
  panel-github-repository: "https://github.com/router-for-me/Cli-Proxy-API-Management-Center"
auth-dir: "<install-root>/auth-dir"
api-keys:
  - "<generated-client-api-key>"
usage-statistics-enabled: true
request-retry: 3
routing:
  strategy: "round-robin"
ws-auth: true
```

Keep the service bound to `127.0.0.1` unless the user explicitly asks for remote access. Do not expose it on all interfaces by default.

## Register launchd

Create a LaunchAgent plist that runs:

```text
<install-root>/bin/cli-proxy-api -config <install-root>/config/config.yaml
```

Set:
- `Label` to a stable name such as `com.<user>.cliproxyapi` or `com.myclaw.cliproxyapi`
- `KeepAlive` to `true`
- `RunAtLoad` to `true`
- `StandardOutPath` and `StandardErrorPath` into the install root `logs/` directory

Copy the plist into `~/Library/LaunchAgents/`, then run:

```bash
launchctl bootstrap gui/$(id -u) ~/Library/LaunchAgents/<label>.plist
launchctl kickstart -k gui/$(id -u)/<label>
```

If a previous agent with the same label exists, inspect it first and either update it deliberately or `bootout` the old one before replacing it.

## Wire OpenClaw

Always back up `~/.openclaw/openclaw.json` before touching it. Use a timestamped backup suffix.

Prefer `jq` to patch JSON. Add a provider like this:

```json
"cliproxy-local": {
  "baseUrl": "http://127.0.0.1:8317/v1",
  "api": "openai-completions",
  "apiKey": "<generated-client-api-key>",
  "models": [
    { "id": "gpt-5.3-codex", "name": "gpt-5.3-codex" },
    { "id": "gpt-5.2-codex", "name": "gpt-5.2-codex" },
    { "id": "gpt-5.1-codex", "name": "gpt-5.1-codex" },
    { "id": "gpt-5.4", "name": "gpt-5.4" }
  ]
}
```

Also add matching entries under `agents.defaults.models`.

Default behavior:
- keep `agents.defaults.model.primary` unchanged
- keep the user's current direct `openai-codex/...` path working
- create a second candidate file that switches primary to `cliproxy-local/gpt-5.3-codex` and uses the old direct model as fallback

This avoids breaking OpenClaw before the user adds any Codex accounts to CLIProxyAPI.

## Verify

Check all of these:

```bash
launchctl print gui/$(id -u)/<label>
lsof -nP -iTCP:8317 -sTCP:LISTEN
curl -sS -H "Authorization: Bearer <generated-client-api-key>" http://127.0.0.1:8317/v1/models
curl -sS http://127.0.0.1:8317/management.html | head -n 5
```

Expected results:
- `launchctl` shows `state = running`
- `lsof` shows `cli-proxy-api` listening on `127.0.0.1:8317`
- `/v1/models` may return `{"data":[],"object":"list"}` before any accounts are added
- `/management.html` returns HTML on `GET`; do not rely on `HEAD`, which may return `404`

If the management page is missing, inspect the service logs and confirm it downloaded the control panel asset successfully.

## Sandbox And Permissions

Expect to need escalated commands for:
- GitHub release queries and downloads
- copying files into `~/Library/LaunchAgents`
- modifying `~/.openclaw/openclaw.json`
- `launchctl` operations
- localhost checks outside the Codex sandbox

If a sandboxed run fails to bind `127.0.0.1:8317` or to reach GitHub, rerun the relevant command with escalation instead of assuming the config is wrong.

## Hand-Off

Tell the user:
- where the install root is
- where the config file is
- the management page URL
- the generated management secret
- that they still need to add one or more Codex OAuth accounts in the management UI

Only switch OpenClaw's default model to `cliproxy-local/...` after the user confirms accounts were added or explicitly asks to make CLIProxyAPI the default immediately.
