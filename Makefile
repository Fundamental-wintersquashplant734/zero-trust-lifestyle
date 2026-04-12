.PHONY: lint shellcheck test bats check install list-packs

SCRIPTS := $(wildcard scripts/*.sh) $(wildcard lib/*.sh) install.sh

lint:
	@for f in $(SCRIPTS); do \
		echo "Checking syntax: $$f"; \
		bash -n "$$f" || exit 1; \
	done
	@echo "All syntax checks passed."

shellcheck:
	@if ! command -v shellcheck >/dev/null 2>&1; then \
		echo "shellcheck not installed — skipping (install: apt install shellcheck)"; \
		exit 0; \
	fi
	@shellcheck -x -S warning $(SCRIPTS)
	@echo "ShellCheck (warnings) passed."

test:
	@for f in scripts/*.sh; do \
		echo "Running --help: $$f"; \
		bash "$$f" --help >/dev/null; \
		exit_code=$$?; \
		if [ $$exit_code -ne 0 ] && [ $$exit_code -ne 1 ]; then \
			echo "FAIL: $$f exited with code $$exit_code"; \
			exit 1; \
		fi; \
	done
	@echo "All smoke tests passed."

bats:
	@if ! command -v bats >/dev/null 2>&1; then \
		echo "bats not installed — skipping (install: apt install bats)"; \
		exit 0; \
	fi
	@bats tests/

check: lint shellcheck test bats

install:
	./install.sh

list-packs:
	./install.sh --list-packs
