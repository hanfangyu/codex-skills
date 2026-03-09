# Codex Skills

A categorized multi-skill repository for Codex, structured to stay compatible with the `skills.sh` / `npx skills` ecosystem.

## Repository Layout

```text
skills/
  <category>/
    <skill-name>/
      SKILL.md
      agents/openai.yaml
```

Current categories:
- `openclaw`

Current skills:
- `openclaw-cli-proxy-setup`

## Install

Install a skill by repository + skill name:

```bash
npx skills add https://github.com/hanfangyu/codex-skills --skill openclaw-cli-proxy-setup
```

Install a skill by direct folder URL:

```bash
npx skills add https://github.com/hanfangyu/codex-skills/tree/main/skills/openclaw/openclaw-cli-proxy-setup
```

After install, invoke it in Codex with:

```text
Use $openclaw-cli-proxy-setup to install CLIProxyAPI, wire it to OpenClaw, and verify the local proxy on this Mac.
```

## Catalog

### openclaw

- `openclaw-cli-proxy-setup`
  Installs CLIProxyAPI on macOS, registers it with `launchd`, adds a local OpenClaw provider, preserves the current default model, and verifies the local `/v1` API plus management UI.

## Adding New Skills

1. Create a category directory under `skills/` if needed.
2. Put each skill in its own folder named after the skill.
3. Keep each skill self-contained with `SKILL.md` and `agents/openai.yaml`.
4. Prefer direct installation compatibility:
   store real skills under `skills/<category>/<skill-name>`.
5. Update this README catalog when a new skill is added.

## Notes

- This repository is intended for portable, reusable Codex skills.
- Keep repository-level docs here; keep skill folders lean.
- For skills that touch local services, auth, or system launch agents, prefer explicit verification and safe defaults over one-shot destructive reconfiguration.
