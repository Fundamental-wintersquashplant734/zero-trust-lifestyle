.PHONY: lint test check install list-packs

lint:
	@for f in scripts/*.sh lib/*.sh; do \
		echo "Checking syntax: $$f"; \
		bash -n "$$f" || exit 1; \
	done
	@echo "All syntax checks passed."

test:
	@for f in scripts/*.sh; do \
		echo "Running --help: $$f"; \
		bash "$$f" --help; \
		exit_code=$$?; \
		if [ $$exit_code -ne 0 ] && [ $$exit_code -ne 1 ]; then \
			echo "FAIL: $$f exited with code $$exit_code"; \
			exit 1; \
		fi; \
	done
	@echo "All smoke tests passed."

check: lint test

install:
	./install.sh

list-packs:
	./install.sh --list-packs
