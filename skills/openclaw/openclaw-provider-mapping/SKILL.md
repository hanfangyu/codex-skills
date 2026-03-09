---
name: openclaw-provider-mapping
description: Add, revise, or rationalize OpenClaw provider mappings that point at CLIProxyAPI, including model aliases, provider names, default model selection, and fallback strategy for Codex, Claude, Gemini, OpenAI-compatible providers, Volcengine Code Plan, Alibaba Bailian Code Plan, and other upstreams exposed through CLIProxyAPI. Use when CLIProxyAPI is already installed or mostly working and the user wants to change provider wiring rather than reinstall the service.
---

# OpenClaw Provider Mapping

Update OpenClaw's provider and model configuration so it calls the right models through an existing CLIProxyAPI instance, while keeping the current setup recoverable.

Do not use this skill as the primary path for first-time installation. If CLIProxyAPI is missing or the user needs a new local service, use `$openclaw-cli-proxy-setup` first.

## Workflow

1. Inspect the current OpenClaw config and any existing CLIProxyAPI config.
2. Identify which upstream providers the user actually wants to expose.
3. Build or revise OpenClaw `models.providers` entries that point to the local CLIProxyAPI `/v1` endpoint.
4. Add matching `agents.defaults.models` entries.
5. Preserve the current primary model unless the user explicitly asks to switch defaults.
6. Create a candidate config for any default-model cutover.
7. Verify the exposed models against `/v1/models` and summarize any mismatch clearly.

## Inspect

Check these first:
- `~/.openclaw/openclaw.json`
- any candidate OpenClaw config files the user already prepared
- the CLIProxyAPI config file if available
- `curl -sS -H "Authorization: Bearer <key>" http://127.0.0.1:8317/v1/models`

If `/v1/models` is empty, call that out immediately. Mapping should follow what CLIProxyAPI actually exposes, not what the user hopes is available.

## Mapping Strategy

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

## Safe Editing Rules

Always back up `~/.openclaw/openclaw.json` before editing.

Prefer `jq` to patch JSON.

Default behavior:
- keep `agents.defaults.model.primary` unchanged
- add new provider models under `agents.defaults.models`
- generate a second candidate file if the user wants to switch the default model
- only replace the primary model immediately when the user explicitly asks for it

If multiple providers are being added at once, keep the naming consistent. Avoid mixing raw upstream IDs and aliases unless there is a concrete routing reason.

## Verification

Verify these after changes:

```bash
jq '.models.providers, .agents.defaults.model, .agents.defaults.models' ~/.openclaw/openclaw.json
curl -sS -H "Authorization: Bearer <key>" http://127.0.0.1:8317/v1/models
```

Check that:
- the local provider exists
- every new model in OpenClaw has a matching exposed model or alias in CLIProxyAPI
- the chosen primary model is actually routable
- fallback models are still valid

## Hand-Off

Tell the user:
- which provider entries were added or changed
- which model aliases are now available in OpenClaw
- whether the default model was left unchanged or switched
- any gaps between desired upstreams and the models currently exposed by CLIProxyAPI

If the mapping task is blocked by missing upstream accounts, say so directly and leave the config in a recoverable state.
