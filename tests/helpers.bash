#!/usr/bin/env bash
# Shared helpers for bats tests.
# Each test runs in an isolated fake project root so we never touch the
# real data/, logs/, or config/ directories.

setup_common() {
    ZT_TEST_ROOT="$(mktemp -d)"
    export ZT_TEST_ROOT
    mkdir -p "$ZT_TEST_ROOT/config" "$ZT_TEST_ROOT/data" "$ZT_TEST_ROOT/logs" "$ZT_TEST_ROOT/lib"

    cp "${BATS_TEST_DIRNAME}/../lib/common.sh" "$ZT_TEST_ROOT/lib/common.sh"

    cat > "$ZT_TEST_ROOT/config/config.sh" <<'EOF'
export ENCRYPTION_PASSWORD="test-password-0123456789abcdefghijklmnopqrstuv"
EOF
    chmod 600 "$ZT_TEST_ROOT/config/config.sh"
}

teardown_common() {
    [[ -n "${ZT_TEST_ROOT:-}" && -d "$ZT_TEST_ROOT" ]] && rm -rf "$ZT_TEST_ROOT"
}
