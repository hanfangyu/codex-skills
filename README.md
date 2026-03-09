# Codex Skills

A categorized multi-skill repository for Codex, structured to stay compatible with the `skills.sh` / `npx skills` ecosystem.

## Repository Layout

```text
skills/
  <category>/
    <skill-name>/
      SKILL.md
      agents/openai.yaml
templates/
  category-skill-template/
scripts/
  validate_skills.rb
```

Current categories:
- `openclaw`

Current skills:
- `openclaw-cli-proxy-setup`
- `openclaw-provider-mapping`

## Install

Install a skill by repository + skill name:

```bash
npx skills add https://github.com/hanfangyu/codex-skills --skill openclaw-cli-proxy-setup
npx skills add https://github.com/hanfangyu/codex-skills --skill openclaw-provider-mapping
```

Install a skill by direct folder URL:

```bash
npx skills add https://github.com/hanfangyu/codex-skills/tree/main/skills/openclaw/openclaw-cli-proxy-setup
npx skills add https://github.com/hanfangyu/codex-skills/tree/main/skills/openclaw/openclaw-provider-mapping
```

After install, invoke it in Codex with:

```text
Use $openclaw-cli-proxy-setup to install CLIProxyAPI, wire it to OpenClaw as a local multi-provider proxy, and verify the setup on this Mac.

Use $openclaw-provider-mapping to add or revise provider mappings, model aliases, and default-model strategy after the local proxy already exists.
```

## Catalog

### openclaw

- `openclaw-cli-proxy-setup`
  Installs CLIProxyAPI on macOS, registers it with `launchd`, adds a local OpenClaw provider, preserves the current default model, and verifies the local `/v1` API plus management UI for broader multi-provider routing across Codex, Claude, Gemini, Volcengine Code Plan, Alibaba Bailian Code Plan, and other compatible upstreams.
- `openclaw-provider-mapping`
  Revises OpenClaw provider entries, model aliases, and default-model strategy against an existing CLIProxyAPI instance so upstreams like Codex, Claude, Gemini, Volcengine Code Plan, Alibaba Bailian Code Plan, and other compatible providers map cleanly into OpenClaw.

## Adding New Skills

1. Create a category directory under `skills/` if needed.
2. Put each skill in its own folder named after the skill.
3. Keep each skill self-contained with `SKILL.md` and `agents/openai.yaml`.
4. Prefer direct installation compatibility:
   store real skills under `skills/<category>/<skill-name>`.
5. Update this README catalog when a new skill is added.

## Template

Use the starter template in:

```text
templates/category-skill-template/
```

Create a new skill by copying it into the target category path:

```bash
mkdir -p skills/<category>
cp -R templates/category-skill-template skills/<category>/<skill-name>
```

Then replace:
- `replace-with-skill-name` in `SKILL.md`
- placeholder text in `SKILL.md`
- `display_name`, `short_description`, and `default_prompt` in `agents/openai.yaml`

The workflow validator only checks `skills/`, so placeholders are allowed inside `templates/`.

## Validation

Local validation:

```bash
ruby scripts/validate_skills.rb
```

CI validation:
- GitHub Actions runs `.github/workflows/validate-skills.yml` on pushes to `main` and on pull requests.
- The validator checks naming, required files, YAML frontmatter, missing metadata, and that `default_prompt` explicitly mentions the matching `$skill-name`.

## Notes

- This repository is intended for portable, reusable Codex skills.
- Keep repository-level docs here; keep skill folders lean.
- For skills that touch local services, auth, or system launch agents, prefer explicit verification and safe defaults over one-shot destructive reconfiguration.
