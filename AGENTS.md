# AGENTS.md

This file contains guidelines and commands for agentic coding agents working in this Ansible collection repository.

## Project Overview

This project is an **Ansible Collection**. The project follows Ansible Galaxy collection standards and practices. Ansible Molecule is used for testing roles in Docker containers.

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

For a complete list of available commands and their usage, run:

```bash
make help
```

This will display all available targets for development, testing, linting, and maintenance operations.

## Important Notes

- Molecule tests require Docker access. If you encounter "Unable to contact the Docker daemon" errors, run tests with `sudo`.
