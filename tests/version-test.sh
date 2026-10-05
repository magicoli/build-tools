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

# A project with no .version: its version comes from composer.json when that is ahead of the last tag, else from the tags
without_version_file() {
    git -C "$PROJECT" rm -q .version
    git -C "$PROJECT" commit -q -m "no .version"
}

function test_without_a_version_file_the_version_follows_the_last_tag() {
    local out
    without_version_file
    git -C "$PROJECT" tag -a v1.0.0 -m "v1.0.0"
    echo more >>"$PROJECT/README.md"
    git -C "$PROJECT" commit -q -am "after the tag"
    out=$(cd "$PROJECT" && "$BT" version)
    assert_matches "VERSION=1\.0\.1-dev\.[0-9]+\+g[0-9a-f]+" "$out"
}

function test_without_a_version_file_the_builds_after_a_pre_release_tag_are_numbered_on_it() {
    local out
    without_version_file
    git -C "$PROJECT" tag -a 3.0.0-beta.4 -m "3.0.0-beta.4"
    echo more >>"$PROJECT/README.md"
    git -C "$PROJECT" commit -q -am "after the tag"
    out=$(cd "$PROJECT" && "$BT" version)
    assert_matches "VERSION=3\.0\.0-beta\.4\.[0-9]+\+g[0-9a-f]+" "$out"
}

function test_the_version_of_composer_json_counts_when_it_is_ahead_of_the_last_tag() {
    local out
    without_version_file
    git -C "$PROJECT" tag -a v1.0.0 -m "v1.0.0"
    printf '{\n    "name": "a/b",\n    "version": "1.2.0"\n}\n' >"$PROJECT/composer.json"
    git -C "$PROJECT" add composer.json
    git -C "$PROJECT" commit -q -m "composer"
    out=$(cd "$PROJECT" && "$BT" version)
    assert_matches "VERSION=1\.2\.0-dev\.[0-9]+\+g[0-9a-f]+" "$out"
}

function test_the_version_of_composer_json_is_not_news_when_it_is_the_last_tag() {
    local out
    without_version_file
    git -C "$PROJECT" tag -a v1.0.0 -m "v1.0.0"
    printf '{\n    "name": "a/b",\n    "version": "1.0.0"\n}\n' >"$PROJECT/composer.json"
    git -C "$PROJECT" add composer.json
    git -C "$PROJECT" commit -q -m "composer"
    out=$(cd "$PROJECT" && "$BT" version)
    assert_matches "VERSION=1\.0\.1-dev\." "$out"
}

function test_no_version_anywhere_is_said() {
    local out
    without_version_file
    out=$(cd "$PROJECT" && "$BT" version 2>&1)
    assert_contains "no version" "$out"
}

function test_a_build_in_a_pre_release_series_comes_after_its_last_release() {
    local out
    git -C "$PROJECT" tag -a 2.0.0-beta.1 -m "2.0.0-beta.1"
    echo 2.0.0-beta.2 >"$PROJECT/.version"
    git -C "$PROJECT" commit -q -am "bump"
    out=$(cd "$PROJECT" && "$BT" version)
    assert_matches "VERSION=2\.0\.0-beta\.1\.[0-9]+\+g[0-9a-f]+" "$out"
}
