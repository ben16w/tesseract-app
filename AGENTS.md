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

Common root files include `Makefile`, `requirements.txt`, `galaxy.yml`,
`README.md`, and this `AGENTS.md`.

## How to Work in This Repo

- Use `make help` first. Treat it as the source of truth for available setup,
  lint, test, and maintenance commands.
- Prefer `Makefile` targets over ad hoc command sequences.
- Before using a target, verify that any paths it references exist in the
  current checkout.
- Keep changes scoped to the relevant role unless a shared change is clearly
  required.

## Ansible Conventions

- Use 2-space YAML indentation and start YAML files with `---`.
- Use fully qualified collection names such as `ansible.builtin.package`.
- Write task names as clear actions.
- Use `.j2` for Jinja2 templates.
- Prefer role-prefixed variables; reserve `tesseract_*` for shared cross-role
  values.
- Put safe defaults in `defaults/main.yml` and validate required inputs in tasks
  with `ansible.builtin.assert`.
- Keep tasks idempotent and use handlers for restarts or reloads.
- Split large roles into focused task files when helpful.

## Testing Guidance

- Molecule scenarios live under `roles/{role_name}/molecule/default/`.
- Prefer validating only the role or roles you changed.
- Use the targets exposed by `make help` instead of hardcoding command choices
  in this file.
- When testing, favor checks for successful converge, important services,
  relevant files, ports, endpoints, and idempotency.
- If Docker or other prerequisites are unavailable, report that clearly.

## Recommended Agent Workflow

1. Inspect the target role and nearby files before editing.
2. Make the smallest change that solves the task.
3. Use `make help` to choose the smallest relevant validation step.
4. Run the appropriate lint or test targets when practical.
5. Report blockers and missing prerequisites explicitly.
