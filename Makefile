SHELL := /bin/bash

# Run all tests for all roles in the repository using molecule.
.PHONY: test
test:
	@set -e ;\
	for roledir in roles/*/molecule; do \
		echo "Testing role: $${roledir}" ;\
		if [ -f $${roledir}/default/molecule.yml ]; then \
			echo "Found molecule.yml for role: $${roledir}" ;\
			pushd $$(dirname $${roledir}) ;\
			molecule test ;\
			popd ;\
		else \
			echo "No molecule.yml found for role: $${roledir}" ;\
		fi ;\
	done

# Run all tests for a roles which have been modified since the last commit using molecule.
.PHONY: test-changed
test-changed:
	@set -e ;\
	for roledir in $$(git diff --name-only HEAD HEAD~1 | grep roles | cut -d '/' -f 2 | uniq); do \
		echo "Testing role: $${roledir}" ;\
		if [ -f $${roledir}/default/molecule.yml ]; then \
			echo "Found molecule.yml for role: $${roledir}" ;\
			pushd $$(dirname $${roledir}) ;\
			molecule test ;\
			popd ;\
		else \
			echo "No molecule.yml found for role: $${roledir}" ;\
		fi ;\
	done

# Lint all roles in the repository using yamllint and ansible-lint.
.PHONY: lint
lint:
	@set -e ;\
	yamllint -d relaxed . ;\
	ansible-lint --profile safety ;\
