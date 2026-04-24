distros := env_var_or_default("DISTRO_LIST", "")

# List available recipes
default:
    @just --list

# ── private helpers ────────────────────────────────────────────────────────────

_venv:
    #!/usr/bin/env bash
    if [ ! -d .venv ]; then
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
    #!/usr/bin/env bash
    set -euo pipefail
    source .venv/bin/activate
    ansible-galaxy install -r requirements.yml

# Create .venv and install Python packages
[group('setup')]
install-venv:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ ! -d .venv ]; then
        python3 -m venv .venv
    fi
    source .venv/bin/activate
    if sudo -n true 2>/dev/null; then
        sudo chown -R "$(stat -c "%U:%G" .)" .venv
    else
        for file in $(find .venv -type f); do
            if ! chown "$(stat -c "%U:%G" .)" "$file" 2>/dev/null; then
                echo "✗ Failed to change virtual environment owner."
                exit 1
            fi
        done
    fi
    pip install -q --upgrade -r requirements.txt
    echo "✔ Virtual environment ready. Run 'source .venv/bin/activate' to activate."

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
        TMP_DIR=$(mktemp -d)
        pushd "$TMP_DIR"
        echo "  → Cloning $(echo "${REPOS}" | cut -d ' ' -f "${COUNTER}")"
        git clone "$(echo "${REPOS}" | cut -d ' ' -f "${COUNTER}")" .
        NEW_COMMIT=$(git rev-parse HEAD)
        echo "  → ${COMMIT} → ${NEW_COMMIT}"
        popd
        sed -i "s/${COMMIT}/${NEW_COMMIT}/g" requirements.yml
        rm -rf "$TMP_DIR"
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
    source .venv/bin/activate
    echo "→ Linting YAML files..."
    find . -type f \
        \( -name "*.yml" -o -name "*.yaml" \) \
        ! -path "./.venv/*" \
        ! -path "./.ansible/*" \
        ! -path "./ansible_collections/*" \
        -print | xargs yamllint -d relaxed
    echo "✔ YAML lint passed."

# Lint shell scripts with shellcheck
[group('lint')]
lint-shell:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "→ Linting shell scripts..."
    for file in $(find . -type f -name '*.sh' \
        ! -path "./.venv/*" \
        ! -path "./.ansible/*" \
        ! -path "./ansible_collections/*"); do
        shellcheck -S warning "$file"
    done
    echo "✔ Shell lint passed."

# Validate Docker Compose files
[group('lint')]
lint-compose:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "→ Linting Docker Compose files..."
    for file in $(find . -type f -name 'docker-compose.*.yml' \
        ! -path "./.venv/*" \
        ! -path "./.ansible/*" \
        ! -path "./ansible_collections/*"); do
        docker compose -f "$file" config --quiet
    done
    echo "✔ Compose lint passed."

# Lint Ansible files with ansible-lint
[group('lint')]
lint-ansible: _venv
    #!/usr/bin/env bash
    set -euo pipefail
    source .venv/bin/activate
    echo "→ Linting Ansible files..."
    if [[ -f "ansible.cfg" || -d "roles" || -d "playbooks" || -d "group_vars" || -d "host_vars" ]]; then
        ANSIBLE_ASK_VAULT_PASS=false ansible-lint \
            --exclude "ansible_collections/" "playbooks/" "docker-compose.*.yml" "vars.yml" \
            -w var-naming[no-role-prefix] \
            -w galaxy[no-changelog] \
            --offline -q
    fi
    echo "✔ Ansible lint passed."

# ── test ───────────────────────────────────────────────────────────────────────

# Run molecule test for a role; empty role tests repo root
[group('test')]
test role="" scenario="default" destroy="true": _venv
    #!/usr/bin/env bash
    set -euo pipefail
    source .venv/bin/activate
    if [ "{{role}}" == "" ]; then
        moleculedir="./molecule"
    else
        moleculedir="roles/{{role}}/molecule"
    fi
    if [ ! -f "${moleculedir}/{{scenario}}/molecule.yml" ]; then
        echo "✗ No molecule.yml found: ${moleculedir}/{{scenario}}/molecule.yml"
        exit 1
    fi
    echo "→ Testing: ${moleculedir} [scenario={{scenario}}]"
    pushd "$(dirname "${moleculedir}")" > /dev/null
    if [ "{{destroy}}" == "true" ]; then
        molecule test --scenario-name "{{scenario}}" --destroy always
    else
        molecule test --scenario-name "{{scenario}}" --destroy never
    fi
    popd > /dev/null
    echo "✔ Test passed."

# Test roles modified since origin/main
[group('test')]
test-changed scenario="default": _venv
    #!/usr/bin/env bash
    set -euo pipefail
    source .venv/bin/activate
    git fetch origin main
    roles=$( (git diff --name-only "$(git merge-base HEAD origin/main)"; git diff --name-only) \
        | grep "roles/" | cut -d '/' -f 1-2 | sort -u)
    for roledir in ${roles}; do
        moleculedir="${roledir}/molecule"
        if [ -f "${moleculedir}/default/molecule.yml" ]; then
            echo "→ Testing: ${moleculedir}"
            pushd "$(dirname "${moleculedir}")"
            INSTANCE_NAME="molecule-${RANDOM}" molecule test
            popd
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
    source .venv/bin/activate
    for moleculedir in roles/*/molecule; do
        if [ -f "${moleculedir}/default/molecule.yml" ]; then
            echo "→ Testing: ${moleculedir}"
            pushd "$(dirname "${moleculedir}")"
            INSTANCE_NAME="molecule-${RANDOM}" molecule test
            popd
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
    source .venv/bin/activate
    if [ -z "{{distros}}" ]; then
        echo "✗ distros is empty. Pass distros='debian12 ubuntu24' or set DISTRO_LIST."
        exit 1
    fi
    for moleculedir in roles/*/molecule; do
        for distro in {{distros}}; do
            if [ -f "${moleculedir}/default/molecule.yml" ]; then
                echo "→ Testing: ${moleculedir} on ${distro}"
                pushd "$(dirname "${moleculedir}")"
                INSTANCE_NAME="molecule-${RANDOM}" MOLECULE_DISTRO="${distro}" molecule test
                popd
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
molecule cmd="test" role="" scenario="default" host="" destroy="true": _venv
    #!/usr/bin/env bash
    set -euo pipefail
    source .venv/bin/activate
    if [ "{{role}}" == "" ]; then
        moleculedir="./molecule"
    else
        moleculedir="roles/{{role}}/molecule"
    fi
    if [ ! -f "${moleculedir}/default/molecule.yml" ]; then
        echo "✗ No molecule.yml found for role: ${moleculedir}"
        exit 1
    fi
    pushd "$(dirname "${moleculedir}")" > /dev/null
    if [ "{{cmd}}" == "test" ]; then
        if [ "{{destroy}}" == "true" ]; then
            molecule test --scenario-name "{{scenario}}" --destroy always
        else
            molecule test --scenario-name "{{scenario}}" --destroy never
        fi
    elif [ "{{cmd}}" == "login" ]; then
        if [ "{{host}}" == "" ]; then
            molecule login --scenario-name "{{scenario}}"
        else
            molecule login --scenario-name "{{scenario}}" -h "{{host}}"
        fi
    else
        molecule "{{cmd}}" --scenario-name "{{scenario}}"
    fi
    popd > /dev/null

# ── deploy ─────────────────────────────────────────────────────────────────────

# Run the playbook with optional tag and host filters
[group('deploy')]
deploy tags="all" lim="all" env="prod": _venv
    #!/usr/bin/env bash
    set -euo pipefail
    source .venv/bin/activate
    ansible-playbook -i inventories/{{env}}/hosts.yml playbooks/{{env}}.yml --tags {{tags}} --limit {{lim}}

# Dry-run the playbook (--check --diff)
[group('deploy')]
check lim="all" env="prod": _venv
    #!/usr/bin/env bash
    set -euo pipefail
    source .venv/bin/activate
    ansible-playbook -i inventories/{{env}}/hosts.yml playbooks/{{env}}.yml --limit {{lim}} --diff --check

# Run an ad-hoc shell command on hosts (cmd is required)
[group('deploy')]
command cmd lim="all" env="prod": _venv
    #!/usr/bin/env bash
    set -euo pipefail
    source .venv/bin/activate
    ansible -i inventories/{{env}}/hosts.yml all -m shell -a "{{cmd}}" --limit {{lim}}

# ── ops ────────────────────────────────────────────────────────────────────────

# Gracefully shut down hosts
[group('ops')]
shutdown lim="all" env="prod": _venv
    #!/usr/bin/env bash
    set -euo pipefail
    source .venv/bin/activate
    ansible -i inventories/{{env}}/hosts.yml all -b -m shell -a "shutdown -h now" --limit {{lim}}

# Edit the encrypted vault for the environment
[group('ops')]
vault env="prod": _venv
    #!/usr/bin/env bash
    set -euo pipefail
    source .venv/bin/activate
    ansible-vault edit inventories/{{env}}/group_vars/all.yml

# Open SSH session to a host
[group('ops')]
ssh host="localhost" user="vagrant" key="~/.vagrant.d/insecure_private_key":
    #!/usr/bin/env bash
    set -euo pipefail
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
