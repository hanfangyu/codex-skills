---
name: openclaw-cli-proxy-setup
description: Install and configure CLIProxyAPI on macOS so OpenClaw can use a local multi-API proxy for Codex, Claude, Gemini, OpenAI-compatible providers, Volcengine Code Plan, Alibaba Bailian Code Plan, and other upstreams exposed through CLIProxyAPI. Use when the user asks to set up, reinstall, migrate, or repair a local CLIProxyAPI + OpenClaw integration, especially for multi-provider routing, launchd autostart, management UI access, account rotation, or OpenClaw model/provider wiring.
---

# OpenClaw CLI Proxy Setup

Install CLIProxyAPI from the official GitHub release, run it as a local `launchd` service, wire OpenClaw to the local `/v1` endpoint, and verify the setup as a general multi-API proxy without breaking the user's current default model before upstream accounts are added.

Treat this skill as OpenClaw-centric, not Codex-centric. Codex is only one possible upstream. The same workflow can support Claude, Gemini, Volcengine Code Plan, Alibaba Bailian Code Plan, and other providers if the final provider entries and model aliases are adjusted to match the user's actual routing plan.

Use this skill for installation, service bootstrap, and first-time local wiring. If the service already exists and the main task is to revise provider aliases, model exposure, or default-model strategy, use `$openclaw-provider-mapping`.

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
8. Hand the user the management URL and explain that upstream provider accounts still need to be added.

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
- one client API key used by OpenClaw and other local clients

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
    { "id": "gpt-5.4", "name": "gpt-5.4" },
    { "id": "gpt-5.3-codex", "name": "gpt-5.3-codex" }
  ]
}
```

Also add matching entries under `agents.defaults.models`.

Treat the model list as user-specific configuration, not a universal default. Include only the model IDs the user actually plans to expose through CLIProxyAPI. Extend or replace the example with Claude, Gemini, OpenAI-compatible aliases, or provider-specific aliases for Volcengine Code Plan and Alibaba Bailian Code Plan when those upstreams are part of the setup.

When Volcengine Code Plan or Alibaba Bailian Code Plan are involved, do not assume a built-in direct provider shape in OpenClaw. If the user is routing them through OpenAI-compatible endpoints or custom provider entries exposed by CLIProxyAPI, model them as the compatible aliases the user will actually call from OpenClaw.

Default behavior:
- keep `agents.defaults.model.primary` unchanged
- keep the user's current direct provider path working
- create a second candidate file that switches primary to `cliproxy-local/gpt-5.3-codex` and uses the old direct model as fallback

This avoids breaking OpenClaw before the user adds provider accounts to CLIProxyAPI.

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
- `/v1/models` may return `{"data":[],"object":"list"}` before any provider accounts are added
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
- that they still need to add one or more provider accounts in the management UI

Only switch OpenClaw's default model to `cliproxy-local/...` after the user confirms accounts were added or explicitly asks to make CLIProxyAPI the default immediately.
