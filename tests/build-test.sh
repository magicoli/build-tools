#!/usr/bin/env bash
# The build: what dist/ holds of a project must be of the same build, or it says so.
#
# Run with: tests/lib/bashunit tests/

source "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

function set_up() {
    new_work
    make_stubs
    make_project 1.0.0-dev
    mkdir -p "$PROJECT/packaging"
    for name in first second; do
        printf 'name: %s\narch: all\nversion: ${VERSION}\nversion_schema: semver\n' "$name" >"$PROJECT/packaging/$name.yaml"
    done
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m "two packages"
}
function tear_down() {
    drop_work
}

build() { # arguments...
    (cd "$PROJECT" && "$BT" build "$@" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
}

function test_a_build_of_every_package_says_nothing_of_dist() {
    assert_not_contains "another build" "$(build deb)"
}

function test_a_build_of_one_package_says_what_dist_holds_of_another_build() {
    local out
    build deb >/dev/null
    echo more >>"$PROJECT/README.md"
    git -C "$PROJECT" commit -q -am "a change"
    out=$(build deb first)
    assert_contains "dist/ has packages of another build: second_" "$out"
    assert_not_contains "first_" "$(grep 'another build' <<<"$out")"
}
