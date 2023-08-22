SHELL := /bin/bash

# Run all tests for all roles in the repository using molecule.
.PHONY: test
test:
	@for roledir in roles/*/molecule; do \
		echo "Testing role: $${roledir}" ;\
		pushd $$(dirname $${roledir}) ;\
		molecule test ;\
		popd ;\
	done
