# AGENTS.md

Guidance for agentic coding agents working in Tesseract Ansible collection
repositories.

## Repository Shape

This repository is an Ansible collection with roles under `roles/`.

```text
roles/{role_name}/
├── defaults/main.yml      # Default variables
├── handlers/main.yml      # Service handlers
├── tasks/main.yml         # Main tasks
├── templates/             # Jinja2 templates (.j2)
├── files/                 # Static files
└── molecule/default/      # Test configuration/
```

## Ansible Conventions

- Use 2-space YAML indentation and start YAML files with `---`.
- Use fully qualified collection names such as `ansible.builtin.package`.
- Write task names as clear actions.
- Use `.j2` for Jinja2 templates.
- Prefer role-prefixed variables; reserve `tesseract_*` for shared cross-role values.
- Put safe defaults in `defaults/main.yml` and validate required inputs in tasks with `ansible.builtin.assert`.
- Keep tasks idempotent and use handlers for restarts or reloads.
- Split large roles into focused task files when helpful.

## How to Work in This Repo

- Use `just` first. Treat it as the source of truth for available setup, lint, test, and maintenance commands.
- Prefer `Justfile` recipes over ad hoc command sequences.
- The `Justfile` is managed externally — do not edit it. Run `./setup.sh` to pull the latest.
- Keep changes scoped to the relevant role unless a shared change is clearly required.
- Use semantic commit messages, all lowercase: `fix`, `feat`, `docs`, `chore`, `refactor`. Keep messages short and simple. Include the role name in parentheses if applicable: `feat(litellm): add gpu support`.

## Testing Guidance

- Prefer validating only the role or roles you changed.
- Prefer `just molecule` over `just test`; it keeps the container between runs for faster iteration. Destroy the container beforehand when a complete rebuild is needed.
- If Docker is unavailable, try running with `sudo`. If that fails, report clearly.

## Recommended Agent Workflow

1. Inspect the target role and nearby files before editing.
2. Make the smallest change that solves the task.
3. Use `just` to choose the smallest relevant validation step.
4. Run the appropriate lint or test targets when practical.
5. Report blockers and missing prerequisites explicitly.
