# Repository Notes

- This repository contains the `tesseract.app` Ansible collection, with roles stored under `roles/`.
- Development flow: `make install-venv`, `make lint`, and `make test ROLE=<role>` for targeted Molecule runs.
- Role conventions here typically use `defaults/main.yml`, `tasks/main.yml`, `handlers/main.yml`, `templates/`, and `molecule/default/`.
- Native-install service roles such as `litellm`, `ollama`, and `scrutiny` install under `/opt/<app>` and manage a systemd service.
