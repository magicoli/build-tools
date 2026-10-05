#!/usr/bin/env bash
# The version of a build: the tag on a release, else the version being worked on with the commits and the hash.
#
# Run with: tests/lib/bashunit tests/

source "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

function set_up() {
    new_work
    make_project 2.0.0-beta.1
}
function tear_down() {
    drop_work
}

function test_a_build_after_the_last_commit_carries_the_commits_and_the_hash() {
    local out hash
    out=$(cd "$PROJECT" && "$BT" version)
    hash=$(git -C "$PROJECT" rev-parse --short HEAD)
    assert_contains "VERSION=2.0.0-beta.1.1+g$hash" "$out"
    assert_contains "DEB_VERSION=2.0.0~beta.1.1+g$hash" "$out"
}

function test_a_build_with_changed_files_says_so() {
    local out
    echo more >>"$PROJECT/README.md"
    out=$(cd "$PROJECT" && "$BT" version)
    assert_contains ".dirty" "$out"
}

function test_a_tagged_release_is_the_tag() {
    local out
    git -C "$PROJECT" tag -a v2.0.0-beta.1 -m "v2.0.0-beta.1"
    out=$(cd "$PROJECT" && "$BT" version)
    assert_equals "VERSION=2.0.0-beta.1
DEB_VERSION=2.0.0~beta.1" "$out"
}
