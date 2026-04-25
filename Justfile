distros := env_var_or_default("DISTRO_LIST", "")
venv := ".venv"

# List available recipes
default:
    @just --list

# ── private helpers ────────────────────────────────────────────────────────────

_venv:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d {{venv}} ]; then
        echo "✗ No virtual environment found. Run 'just install-venv' first."
        exit 1
    fi

# ── setup ──────────────────────────────────────────────────────────────────────

# Set up venv then install Galaxy roles
[group('setup')]
bootstrap: install-venv install

# Install Ansible Galaxy roles from requirements.yml
[group('setup')]
install: _venv
    {{venv}}/bin/ansible-galaxy install -r requirements.yml

# Create .venv and install Python packages
[group('setup')]
install-venv:
    #!/usr/bin/env bash
    set -euo pipefail
    test -d {{venv}} || python3 -m venv {{venv}}
    {{venv}}/bin/python -m pip install -q --upgrade pip
    {{venv}}/bin/pip install -q --upgrade -r requirements.txt
    echo "✔ Virtual environment ready. Run 'source .venv/bin/activate' to activate."

# Repair .venv file ownership (use when venv was created by a different user)
[group('setup')]
fix-venv: _venv
    #!/usr/bin/env bash
    set -euo pipefail
    if sudo -n true 2>/dev/null; then
        sudo chown -R "$(stat -c "%U:%G" .)" {{venv}}
    else
        find {{venv}} -type f -exec chown "$(stat -c "%U:%G" .)" {} + 2>/dev/null || \
            { echo "✗ Failed to change virtual environment owner."; exit 1; }
    fi
    echo "✔ Virtual environment ownership repaired."

# Symlink local collections into the Ansible collections path
[group('setup')]
link-collections collections="." project="../" suffix="roles-":
    #!/usr/bin/env bash
    set -euo pipefail
    for COLLECTION in $(ls -d {{collections}}/ansible_collections/tesseract/*); do
        COLLECTION_NAME=$(basename "${COLLECTION}")
        REAL_PROJECT_PATH=$(realpath "{{project}}")
        echo "  → ${COLLECTION} → ${REAL_PROJECT_PATH}/{{suffix}}${COLLECTION_NAME}"
        if [ ! -d "${REAL_PROJECT_PATH}/{{suffix}}${COLLECTION_NAME}" ]; then
            echo "✗ Project path does not exist: ${REAL_PROJECT_PATH}/{{suffix}}${COLLECTION_NAME}"
            exit 1
        fi
        rm -rf "${COLLECTION}"
        ln -s "${REAL_PROJECT_PATH}/{{suffix}}${COLLECTION_NAME}" "${COLLECTION}"
    done
    echo "✔ Collections linked."

# ── update ─────────────────────────────────────────────────────────────────────

# Update requirements.yml commit hashes to latest HEAD
[group('update')]
update-requirements:
    #!/usr/bin/env bash
    set -euo pipefail
    COMMITS=$(grep -E "version:" requirements.yml | cut -d ":" -f 2 | tr -d ' ')
    REPOS=$(grep -E "name:" requirements.yml | grep "tesseract" | cut -d ":" -f 2,3 | tr -d ' ')
    COUNTER=1
    for COMMIT in ${COMMITS}; do
        REPO=$(echo "${REPOS}" | cut -d ' ' -f "${COUNTER}")
        echo "  → Fetching HEAD for ${REPO}"
        NEW_COMMIT=$(git ls-remote "${REPO}" HEAD | cut -f1)
        echo "  → ${COMMIT} → ${NEW_COMMIT}"
        sed -i "s/${COMMIT}/${NEW_COMMIT}/g" requirements.yml
        COUNTER=$((COUNTER + 1))
    done
    echo "✔ requirements.yml updated."

# Sync all role molecule.yml files from repo root template
[group('update')]
update-molecule:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -f molecule.yml ]; then
        echo "✗ No molecule.yml found in repository root."
        exit 1
    fi
    for moleculedir in roles/*/molecule; do
        if [ ! -f "${moleculedir}/default/molecule.yml" ]; then
            echo "✗ No molecule.yml found for role: ${moleculedir}"
            exit 1
        fi
        if cmp -s molecule.yml "${moleculedir}/default/molecule.yml"; then
            echo "  ~ ${moleculedir}: already up to date, skipping."
        else
            cp molecule.yml "${moleculedir}/default/molecule.yml"
            echo "  ✔ ${moleculedir}: updated."
        fi
    done
    echo "✔ molecule.yml sync complete."

# ── lint ───────────────────────────────────────────────────────────────────────

# Run all linters in sequence
[group('lint')]
lint: lint-yaml lint-shell lint-compose lint-ansible

# Lint YAML files with yamllint
[group('lint')]
lint-yaml: _venv
    #!/usr/bin/env bash
    set -euo pipefail
    echo "→ Linting YAML files..."
    find . -type f \
        \( -name "*.yml" -o -name "*.yaml" \) \
        ! -path "./.venv/*" \
        ! -path "./.ansible/*" \
        ! -path "./ansible_collections/*" \
        -exec {{venv}}/bin/yamllint -d relaxed {} +
    echo "✔ YAML lint passed."

# Lint shell scripts with shellcheck
[group('lint')]
lint-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "→ Linting shell scripts..."
    find . -type f -name '*.sh' \
        ! -path "./.venv/*" \
        ! -path "./.ansible/*" \
        ! -path "./ansible_collections/*" \
        -exec shellcheck -S warning {} +
    echo "✔ Shell lint passed."

# Validate Docker Compose files
[group('lint')]
lint-compose:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "→ Linting Docker Compose files..."
    find . -type f -name 'docker-compose.*.yml' \
        ! -path "./.venv/*" \
        ! -path "./.ansible/*" \
        ! -path "./ansible_collections/*" \
        -exec docker compose -f {} config --quiet \;
    echo "✔ Compose lint passed."

# Lint Ansible files with ansible-lint
[group('lint')]
lint-ansible: _venv
    #!/usr/bin/env bash
    set -euo pipefail
    echo "→ Linting Ansible files..."
    if [[ -f "ansible.cfg" || -d "roles" || -d "playbooks" || -d "group_vars" || -d "host_vars" ]]; then
        ANSIBLE_ASK_VAULT_PASS=false {{venv}}/bin/ansible-lint \
            --exclude "ansible_collections/" "playbooks/" "docker-compose.*.yml" "vars.yml" \
            -w var-naming[no-role-prefix] \
            -w galaxy[no-changelog] \
            --offline -q
    fi
    echo "✔ Ansible lint passed."

# ── test ───────────────────────────────────────────────────────────────────────

# Run molecule test for a role; empty role tests repo root
[group('test')]
test role="" scenario="default" destroy="true":
    echo "→ Testing: {{role}} [scenario={{scenario}}]"
    just molecule "test" "{{role}}" "{{scenario}}" "{{destroy}}"
    echo "✔ Test passed."

# Test roles modified since origin/main
[group('test')]
test-changed scenario="default": _venv
    #!/usr/bin/env bash
    set -euo pipefail
    git fetch origin main
    roles=$( (git diff --name-only "$(git merge-base HEAD origin/main)"; git diff --name-only) \
        | grep "roles/" | cut -d '/' -f 1-2 | sort -u)
    for roledir in ${roles}; do
        role=$(basename "${roledir}")
        moleculedir="${roledir}/molecule"
        if [ -f "${moleculedir}/{{scenario}}/molecule.yml" ]; then
            echo "→ Testing: ${moleculedir}"
            INSTANCE_NAME="molecule-${RANDOM}" just molecule "test" "${role}" "{{scenario}}"
            echo "  ✔ ${moleculedir} passed."
        else
            echo "  ~ ${moleculedir}: no molecule.yml, skipping."
        fi
    done
    echo "✔ All changed roles tested."

# Test every role in the collection
[group('test')]
test-all scenario="default": _venv
    #!/usr/bin/env bash
    set -euo pipefail
    for moleculedir in roles/*/molecule; do
        role=$(basename "$(dirname "${moleculedir}")")
        if [ -f "${moleculedir}/{{scenario}}/molecule.yml" ]; then
            echo "→ Testing: ${moleculedir}"
            INSTANCE_NAME="molecule-${RANDOM}" just molecule "test" "${role}" "{{scenario}}"
            echo "  ✔ ${moleculedir} passed."
        else
            echo "  ~ ${moleculedir}: no molecule.yml, skipping."
        fi
    done
    echo "✔ All roles tested."

# Test every role across each distro (space-separated); overrides $DISTRO_LIST
[group('test')]
test-all-distros scenario="default" distros=distros: _venv
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -z "{{distros}}" ]; then
        echo "✗ distros is empty. Pass distros='debian12 ubuntu24' or set DISTRO_LIST."
        exit 1
    fi
    for moleculedir in roles/*/molecule; do
        role=$(basename "$(dirname "${moleculedir}")")
        for distro in {{distros}}; do
            if [ -f "${moleculedir}/{{scenario}}/molecule.yml" ]; then
                echo "→ Testing: ${moleculedir} on ${distro}"
                INSTANCE_NAME="molecule-${RANDOM}" MOLECULE_DISTRO="${distro}" just molecule "test" "${role}" "{{scenario}}"
                echo "  ✔ ${moleculedir} [${distro}] passed."
            else
                echo "  ~ ${moleculedir}: no molecule.yml, skipping."
            fi
        done
    done
    echo "✔ All roles tested across all distros."

# ── molecule ───────────────────────────────────────────────────────────────────

# Run any molecule command in the role dir (cmd: test/converge/login/destroy/idempotence/verify/syntax)
[group('molecule')]
molecule cmd="test" role="" scenario="default" destroy="true" host="": _venv
    #!/usr/bin/env bash
    set -euo pipefail
    if [ "{{role}}" == "" ]; then
        moleculedir="./molecule"
    else
        moleculedir="roles/{{role}}/molecule"
    fi
    if [ ! -f "${moleculedir}/{{scenario}}/molecule.yml" ]; then
        echo "✗ No molecule.yml found for role: ${moleculedir}"
        exit 1
    fi
    args=(--scenario-name "{{scenario}}")
    if [ "{{cmd}}" == "test" ]; then
        if [ "{{destroy}}" == "true" ]; then
            args+=(--destroy always)
        else
            args+=(--destroy never)
        fi
    elif [ "{{cmd}}" == "login" ] && [ -n "{{host}}" ]; then
        args+=(-h "{{host}}")
    fi
    MOLECULE_BIN="$(realpath "{{venv}}/bin/molecule")"
    (
        cd "$(dirname "${moleculedir}")"
        "${MOLECULE_BIN}" "{{cmd}}" "${args[@]}"
    )

# ── deploy ─────────────────────────────────────────────────────────────────────

# Run the playbook with optional tag and host filters
[group('deploy')]
deploy tags="all" lim="all" env="prod": _venv
    {{venv}}/bin/ansible-playbook -i inventories/{{env}}/hosts.yml playbooks/{{env}}.yml --tags {{tags}} --limit {{lim}}

# Dry-run the playbook (--check --diff)
[group('deploy')]
check lim="all" env="prod": _venv
    {{venv}}/bin/ansible-playbook -i inventories/{{env}}/hosts.yml playbooks/{{env}}.yml --limit {{lim}} --diff --check

# Run an ad-hoc shell command on hosts (cmd is required)
[group('deploy')]
command cmd lim="all" env="prod": _venv
    {{venv}}/bin/ansible -i inventories/{{env}}/hosts.yml all -m shell -a "{{cmd}}" --limit {{lim}}

# ── ops ────────────────────────────────────────────────────────────────────────

# Gracefully shut down hosts
[group('ops')]
shutdown lim="all" env="prod": _venv
    {{venv}}/bin/ansible -i inventories/{{env}}/hosts.yml all -b -m shell -a "shutdown -h now" --limit {{lim}}

# Edit the encrypted vault for the environment
[group('ops')]
vault env="prod": _venv
    {{venv}}/bin/ansible-vault edit inventories/{{env}}/group_vars/all.yml

# Open SSH session to a host
[group('ops')]
ssh host="localhost" user="vagrant" key="$HOME/.vagrant.d/insecure_private_key":
    ssh -i "{{key}}" -o StrictHostKeyChecking=no "{{user}}@{{host}}"

# Power off and unregister all VirtualBox VMs
[group('ops')]
[confirm]
delete-vms:
    #!/usr/bin/env bash
    set -euo pipefail
    VBoxManage list runningvms | awk '{print $2}' | xargs -I{} VBoxManage controlvm {} poweroff
    VBoxManage list vms | awk '{print $2}' | xargs -I{} VBoxManage unregistervm {}
    rm -rf ~/VirtualBox\ VMs/*
