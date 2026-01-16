# AGENTS.md

This file contains guidelines and commands for agentic coding agents working in this Ansible collection repository.

## Project Overview

This project is an **Ansible Collection**. The project follows Ansible Galaxy collection standards and practices. Anisble Molecule is used for testing roles in Docker containers.

## Technology Stack

- **Ansible**: Configuration management
- **Molecule**: Testing framework with Docker driver
- **Python**: Runtime environment
- **Docker**: Container platform for testing and services

## Role Structure

Each role follows this standard structure:

```
roles/{role_name}/
├── defaults/main.yml      # Default variables
├── tasks/main.yml         # Main tasks
├── handlers/main.yml      # Service handlers
├── templates/             # Jinja2 templates (.j2)
├── files/                 # Static files
└── molecule/default/      # Test configuration
```

## Code Style Guidelines

### YAML/Ansible Conventions

- **Indentation**: 2 spaces for YAML
- **File headers**: Always start with `---`
- **Module naming**: Use fully qualified collection names (`ansible.builtin.user`, `ansible.builtin.package`)
- **Task names**: Descriptive, starting with verbs ("Ensure", "Create", "Install")
- **Line length**: ~80-100 characters
- **Templates**: Template files use .j2 extension
- **Variables**: Global variables: {service}_ prefix
- **Defaults**: Always assert required inputs

## Molecule Testing

Each role includes a Molecule scenario for testing located in `roles/{role_name}/molecule/default/`:

### Files

- **`molecule.yml`**: Molecule configuration defining test infrastructure
- **`converge.yml`**: Main test playbook that applies the role
- **`verify.yml`**: Verification playbook that validates role execution
- **`prepare.yml`**: Optional setup playbook for test dependencies
- **`vars.yml`**: Optional external variables file

### Workflow

1. **Create**: Spins up Docker container(s)
2. **Prepare**: Runs prepare.yml (if exists)
3. **Converge**: Applies the role via converge.yml
4. **Verify**: Runs verification tests via verify.yml
5. **Destroy**: Tears down containers

### Best Practices

- Always verify service state and port availability
- Include API/functionality tests where applicable
- Test both positive and negative scenarios (auth, validation)
- Use mock services for external dependencies
- Keep test variables minimal but realistic
- Ensure idempotency by running converge twice

## Command Reference

### Development Environment Setup

```bash
# Create virtual environment and install dependencies
make install-venv
```

### Testing Commands

```bash
# Test a specific role (most common)
make test ROLE=litellm

# Test only modified roles (for feature branches)
make test-changed

# Test all roles
make test-all

# Test all roles on all distributions
make test-all-distros DISTRO_LIST="ubuntu2204 ubuntu2004 debian12"

# Run specific molecule command
make test ROLE=litellm CMD=converge
make test ROLE=litellm CMD=login
```

### Linting and Validation

```bash
# Run all linting checks (Docker, shell, YAML, Ansible)
make lint

# Individual linting tools (if needed)
yamllint -d relaxed .
ansible-lint playbooks/ docker-compose.*.yml vars.yml
shellcheck **/*.sh
docker compose -f docker-compose.*.yml config --quiet
```

### Build and Maintenance

```bash
# Update git commit hashes in requirements.yml
make update-requirements

# Sync molecule.yml files across all roles
make update-molecule

# Install Ansible Galaxy roles
make install
```

## Important Notes

- Molecule tests require Docker access. If you encounter "Unable to contact the Docker daemon" errors, run tests with `sudo`.
