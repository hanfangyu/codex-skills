---
name: openclaw-cli-proxy-setup
description: Install, repair, or revise CLIProxyAPI on macOS so OpenClaw can use a local multi-provider proxy for Codex, Claude, Gemini, OpenAI-compatible providers, Volcengine Code Plan, Alibaba Bailian Code Plan, and other upstreams exposed through CLIProxyAPI. Use when the user asks to set up, reinstall, migrate, verify, or rewire a local CLIProxyAPI + OpenClaw integration, including launchd autostart, management UI access, provider aliases, model exposure, default model strategy, or OpenClaw model/provider wiring.
---

# OpenClaw CLI Proxy Setup

Install CLIProxyAPI from the official GitHub release, run it as a local `launchd` service, wire OpenClaw to the local `/v1` endpoint, and verify the setup as a general multi-API proxy without breaking the user's current default model before upstream accounts are added.

Treat this skill as OpenClaw-centric, not Codex-centric. Codex is only one possible upstream. The same workflow can support Claude, Gemini, Volcengine Code Plan, Alibaba Bailian Code Plan, and other providers if the final provider entries and model aliases are adjusted to match the user's actual routing plan.

Prefer the safe path:
- add a new OpenClaw provider
- keep the current OpenClaw primary model unchanged
- create a separate candidate config if the user later wants CLIProxyAPI to become the default

Do not follow Linux/Docker tutorials verbatim on macOS. Use the official macOS binary release unless the user explicitly asks for another installation method.

## Choose The Path

Use the same skill with different user instructions:
- install or rebuild:
  `用 $openclaw-cli-proxy-setup 给这台 Mac 安装或重装 CLIProxyAPI，并接到 OpenClaw`
- remap providers or models:
  `用 $openclaw-cli-proxy-setup 调整 OpenClaw 的 provider 映射、模型 alias 和默认模型策略`

Choose the workflow based on the real task:
- if CLIProxyAPI is missing, broken, or needs launchd/bootstrap work, use the install workflow
- if CLIProxyAPI already exists and the main task is provider aliases, model exposure, fallback design, or default-model cutover, use the mapping workflow

## Install Workflow

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

## Mapping Workflow

Use this path when CLIProxyAPI is already installed or mostly working and the user wants to revise provider wiring rather than reinstall the service.

1. Inspect the current OpenClaw config and any existing CLIProxyAPI config.
2. Identify which upstream providers the user actually wants to expose.
3. Build or revise OpenClaw `models.providers` entries that point to the local CLIProxyAPI `/v1` endpoint.
4. Add matching `agents.defaults.models` entries.
5. Preserve the current primary model unless the user explicitly asks to switch defaults.
6. Create a candidate config for any default-model cutover.
7. Verify the exposed models against `/v1/models` and summarize any mismatch clearly.

Check these first:
- `~/.openclaw/openclaw.json`
- any candidate OpenClaw config files the user already prepared
- the CLIProxyAPI config file if available
- `curl -sS -H "Authorization: Bearer <key>" http://127.0.0.1:8317/v1/models`

If `/v1/models` is empty, call that out immediately. Mapping should follow what CLIProxyAPI actually exposes, not what the user hopes is available.

Treat OpenClaw as a consumer of a local OpenAI-compatible endpoint. The main job is to make names line up cleanly.

Prefer one stable local provider such as:

```json
"cliproxy-local": {
  "baseUrl": "http://127.0.0.1:8317/v1",
  "api": "openai-completions",
  "apiKey": "<client-api-key>",
  "models": [
    { "id": "provider-alias/model-a", "name": "provider-alias/model-a" },
    { "id": "provider-alias/model-b", "name": "provider-alias/model-b" }
  ]
}
```

Use the model IDs that OpenClaw should call, not necessarily the upstream raw names. If CLIProxyAPI rewrites or aliases names, mirror those aliases here.

Common patterns:
- direct codex-style aliases such as `gpt-5.3-codex`
- claude aliases exposed through CLIProxyAPI
- gemini aliases exposed through CLIProxyAPI
- OpenAI-compatible aliases for Volcengine Code Plan or Alibaba Bailian Code Plan
- provider-prefixed names when the user wants explicit routing separation

When Volcengine Code Plan or Alibaba Bailian Code Plan are routed through OpenAI-compatible endpoints, treat them as compatible model aliases rather than assuming OpenClaw has native provider semantics for them.

Always back up `~/.openclaw/openclaw.json` before editing.

Prefer `jq` to patch JSON.

Mapping defaults:
- keep `agents.defaults.model.primary` unchanged
- add new provider models under `agents.defaults.models`
- generate a second candidate file if the user wants to switch the default model
- only replace the primary model immediately when the user explicitly asks for it

If multiple providers are being added at once, keep the naming consistent. Avoid mixing raw upstream IDs and aliases unless there is a concrete routing reason.

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

For mapping-only tasks, also verify:

```bash
jq '.models.providers, .agents.defaults.model, .agents.defaults.models' ~/.openclaw/openclaw.json
curl -sS -H "Authorization: Bearer <key>" http://127.0.0.1:8317/v1/models
```

Check that:
- the local provider exists
- every new model in OpenClaw has a matching exposed model or alias in CLIProxyAPI
- the chosen primary model is actually routable
- fallback models are still valid

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

For mapping-only tasks, also tell the user:
- which provider entries were added or changed
- which model aliases are now available in OpenClaw
- whether the default model was left unchanged or switched
- any gaps between desired upstreams and the models currently exposed by CLIProxyAPI
