#!/usr/bin/env bats
# Tests for lib/common.sh — the shared library every script depends on.
# Each test sources lib/common.sh from an isolated fake project root so
# it never touches the real data/, logs/, or config/.

load helpers.bash

setup()    { setup_common; }
teardown() { teardown_common; }

@test "encrypt_data + decrypt_data roundtrip" {
    run bash -c "cd '$ZT_TEST_ROOT' && source lib/common.sh && encrypt_data 'hello world' data/msg.enc && decrypt_data data/msg.enc"
    [ "$status" -eq 0 ]
    [ "$output" = "hello world" ]
}

@test "encrypt_data fails loudly without ENCRYPTION_PASSWORD" {
    # Use a nested subdir that has no config/config.sh at all so lib/common.sh
    # doesn't pick up our test password. Don't mutate the shared config file
    # used by the other tests in this file.
    mkdir -p "$ZT_TEST_ROOT/sub/config" "$ZT_TEST_ROOT/sub/data" "$ZT_TEST_ROOT/sub/logs" "$ZT_TEST_ROOT/sub/lib"
    cp "${BATS_TEST_DIRNAME}/../lib/common.sh" "$ZT_TEST_ROOT/sub/lib/common.sh"
    run bash -c "cd '$ZT_TEST_ROOT/sub' && unset ENCRYPTION_PASSWORD && source lib/common.sh 2>&1 && encrypt_data 'x' data/x.enc"
    [ "$status" -ne 0 ]
    [[ "$output" == *"ENCRYPTION_PASSWORD is not set"* ]]
}

@test "http_get refuses file:// URLs" {
    run bash -c "cd '$ZT_TEST_ROOT' && source lib/common.sh && http_get 'file:///etc/passwd'"
    [ "$status" -ne 0 ]
    [[ "$output" == *"refusing non-http"* ]]
}

@test "http_get refuses URLs with CRLF" {
    run bash -c "cd '$ZT_TEST_ROOT' && source lib/common.sh && http_get \$'http://example.com/\r\nInjected: 1'"
    [ "$status" -ne 0 ]
    [[ "$output" == *"refusing"* ]]
}

@test "rate_limit blocks after N calls" {
    run bash -c "cd '$ZT_TEST_ROOT' && source lib/common.sh && rate_limit testaction 3 60 && rate_limit testaction 3 60 && rate_limit testaction 3 60 && rate_limit testaction 3 60"
    [ "$status" -ne 0 ]
}

@test "config file with group-write is refused" {
    chmod 660 "$ZT_TEST_ROOT/config/config.sh"
    run bash -c "cd '$ZT_TEST_ROOT' && source lib/common.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"REFUSING to source"* ]]
}

@test "config file with world-write is refused" {
    chmod 662 "$ZT_TEST_ROOT/config/config.sh"
    run bash -c "cd '$ZT_TEST_ROOT' && source lib/common.sh"
    [ "$status" -ne 0 ]
    [[ "$output" == *"REFUSING to source"* ]]
}
