#!/usr/bin/env bash
# apt-package: the packages of packaging/*.yaml with the version of the project, published to the suite that fits each
# one: the pre-releases to their own suite when the repository has one.
#
# Run with: tests/lib/bashunit tests/

source "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

function set_up() {
    new_work
    make_stubs
    make_apt_repo
    make_project 1.2.3
    mkdir -p "$PROJECT/packaging"
    printf 'name: demo\narch: all\nversion: ${VERSION}\nversion_schema: semver\n' >"$PROJECT/packaging/demo.yaml"
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m "a package"
    git -C "$PROJECT" tag -a v1.2.3 -m "v1.2.3"
    export APT_PUBLISH="$WORK/bin/apt-publish-stub"
}
function tear_down() {
    drop_work
}

function test_it_builds_the_package_with_the_version_of_the_tag() {
    (cd "$PROJECT" && "$ROOT/bin/apt-package" >/dev/null 2>&1)
    assert_file_exists "$PROJECT/dist/demo_1.2.3_all.deb"
    assert_contains "version: 1.2.3" "$(cat "$STUB_STATE/last-definition.yaml")"
}

function test_a_build_after_the_tag_is_the_version_in_progress_with_the_commits_and_the_hash() {
    echo 1.2.4-dev >"$PROJECT/.version"
    git -C "$PROJECT" commit -q -am "after the tag"
    (cd "$PROJECT" && "$ROOT/bin/apt-package" >/dev/null 2>&1)
    assert_matches "version: 1\.2\.4-dev\.[0-9]+\+g[0-9a-f]+" "$(cat "$STUB_STATE/last-definition.yaml")"
}

function test_the_package_has_the_version_of_the_zip_and_of_the_release() {
    local version
    echo 1.2.4-dev >"$PROJECT/.version"
    git -C "$PROJECT" commit -q -am "after the tag"
    version=$(cd "$PROJECT" && "$BT" version | sed -n 's/^VERSION=//p')
    (cd "$PROJECT" && "$ROOT/bin/apt-package" >/dev/null 2>&1)
    assert_contains "version: $version" "$(cat "$STUB_STATE/last-definition.yaml")"
}

function test_it_does_not_publish_without_a_repository() {
    local out
    unset APT_REPO_DIR
    out=$(cd "$PROJECT" && "$ROOT/bin/apt-package" --publish 2>&1)
    assert_contains "APT_REPO_DIR is not set" "$out"
}

function test_the_prereleases_go_to_their_own_suite() {
    printf 'name: stable-one\narch: all\nversion: 1.0.0\n' >"$PROJECT/packaging/stable-one.yaml"
    printf 'name: pre-one\narch: all\nversion: 2.0.0~beta.1\n' >"$PROJECT/packaging/pre-one.yaml"
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m "two more packages"
    git -C "$PROJECT" tag -a v1.2.4 -m "v1.2.4"
    export APT_REPO_PRERELEASE_DIST=unstable
    (cd "$PROJECT" && "$ROOT/bin/apt-package" --publish >/dev/null 2>&1)
    assert_contains "apt-publish dist=stable " "$(calls)"
    assert_contains "stable-one_1.0.0_all.deb" "$(grep 'dist=stable ' "$STUB_LOG")"
    assert_contains "apt-publish dist=unstable pre-one_2.0.0~beta.1_all.deb" "$(calls)"
}

function test_without_a_prerelease_suite_all_go_to_the_same_one() {
    printf 'name: pre-one\narch: all\nversion: 2.0.0~beta.1\n' >"$PROJECT/packaging/pre-one.yaml"
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m "a pre-release"
    git -C "$PROJECT" tag -a v1.2.4 -m "v1.2.4"
    (cd "$PROJECT" && "$ROOT/bin/apt-package" --publish >/dev/null 2>&1)
    assert_equals "1" "$(grep -c '^apt-publish' "$STUB_LOG")"
    assert_contains "dist=stable" "$(grep '^apt-publish' "$STUB_LOG")"
}
