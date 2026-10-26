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

function test_a_file_left_by_a_former_build_does_not_give_its_version() {
    mkdir -p "$PROJECT/build"
    printf 'VERSION=9.9.9\nDEB_VERSION=9.9.9\n' >"$PROJECT/build/packaging.env"
    (cd "$PROJECT" && "$ROOT/bin/apt-package" >/dev/null 2>&1)
    assert_file_exists "$PROJECT/dist/demo_1.2.3_all.deb"
    assert_contains "version: 1.2.3" "$(cat "$STUB_STATE/last-definition.yaml")"
}

function test_it_does_not_publish_without_a_repository() {
    local out
    unset APT_REPO_DIR
    out=$(cd "$PROJECT" && "$ROOT/bin/apt-package" --publish 2>&1)
    assert_contains "APT_REPO_DIR is not set" "$out"
}

function test_the_prereleases_go_to_their_component_and_packages_route_by_name() {
    printf 'name: stable-one\narch: all\nversion: 1.0.0\n' >"$PROJECT/packaging/stable-one.yaml"
    printf 'name: pre-one\narch: all\nversion: 2.0.0~beta.1\n' >"$PROJECT/packaging/pre-one.yaml"
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m "two more packages"
    git -C "$PROJECT" tag -a v1.2.4 -m "v1.2.4"
    export APT_REPO_PRERELEASE_COMPONENT=unstable
    (cd "$PROJECT" && "$ROOT/bin/apt-package" --publish >/dev/null 2>&1)
    assert_contains "apt-publish dist=main component=stable " "$(calls)"
    assert_contains "stable-one_1.0.0_all.deb" "$(grep 'dist=main component=stable ' "$STUB_LOG")"
    assert_contains "apt-publish dist=main component=unstable pre-one_2.0.0~beta.1_all.deb" "$(calls)"
}

function test_a_revision_of_debian_stays_in_the_suite_of_the_releases() {
    printf 'name: rev-one\narch: all\nversion: 0.9.3.0-1\n' >"$PROJECT/packaging/rev-one.yaml"
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m "a package with a revision"
    git -C "$PROJECT" tag -a v1.2.5 -m "v1.2.5"
    export APT_REPO_PRERELEASE_COMPONENT=unstable
    (cd "$PROJECT" && "$ROOT/bin/apt-package" --publish >/dev/null 2>&1)
    assert_contains "rev-one_0.9.3.0-1_all.deb" "$(grep 'dist=main component=stable ' "$STUB_LOG")"
    assert_not_contains "rev-one" "$(grep 'component=unstable ' "$STUB_LOG" || true)"
}

function test_a_package_already_in_its_target_is_not_published_again() {
    local out
    printf 'name: pre-one\narch: all\nversion: 2.0.0~beta.1\n' >"$PROJECT/packaging/pre-one.yaml"
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m "a pre-release"
    git -C "$PROJECT" tag -a v1.2.4 -m "v1.2.4"
    export APT_REPO_PRERELEASE_COMPONENT=unstable
    echo "main unstable pre-one_2.0.0~beta.1_all.deb" >>"$APT/db/packages.db"
    out=$(cd "$PROJECT" && "$ROOT/bin/apt-package" --publish 2>&1)
    assert_contains "Already published: pre-one_2.0.0~beta.1_all.deb" "$out"
    assert_not_contains "pre-one" "$(grep '^apt-publish' "$STUB_LOG" || true)"
}

function test_a_package_in_another_component_is_published_to_its_target() {
    printf 'name: pre-one\narch: all\nversion: 2.0.0~beta.1\n' >"$PROJECT/packaging/pre-one.yaml"
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m "a pre-release"
    git -C "$PROJECT" tag -a v1.2.4 -m "v1.2.4"
    export APT_REPO_PRERELEASE_COMPONENT=unstable
    echo "main stable pre-one_2.0.0~beta.1_all.deb" >>"$APT/db/packages.db"
    (cd "$PROJECT" && "$ROOT/bin/apt-package" --publish >/dev/null 2>&1)
    assert_contains "apt-publish dist=main component=unstable pre-one_2.0.0~beta.1_all.deb" "$(calls)"
}

function test_without_a_prerelease_component_all_go_to_the_stable_component() {
    printf 'name: pre-one\narch: all\nversion: 2.0.0~beta.1\n' >"$PROJECT/packaging/pre-one.yaml"
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m "a pre-release"
    git -C "$PROJECT" tag -a v1.2.4 -m "v1.2.4"
    (cd "$PROJECT" && "$ROOT/bin/apt-package" --publish >/dev/null 2>&1)
    assert_equals "1" "$(grep -c '^apt-publish' "$STUB_LOG")"
    assert_contains "dist=main component=stable" "$(grep '^apt-publish' "$STUB_LOG")"
}

function test_packages_are_routed_by_name_to_configured_codenames() {
    printf 'name: core-cli\narch: all\nversion: 3.0.0\n' >"$PROJECT/packaging/core-cli.yaml"
    printf 'name: wrap-tools\narch: all\nversion: 3.0.0\n' >"$PROJECT/packaging/wrap-tools.yaml"
    printf 'name: bash-tools\narch: all\nversion: 1.0.0\n' >"$PROJECT/packaging/bash-tools.yaml"
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m "route packages"
    git -C "$PROJECT" tag -a v1.2.4 -m "v1.2.4"
    (cd "$PROJECT" && "$ROOT/bin/apt-package" --publish >/dev/null 2>&1)
    assert_contains "dist=core component=stable core-cli_3.0.0_all.deb" "$(calls)"
    assert_contains "dist=wrap component=stable wrap-tools_3.0.0_all.deb" "$(calls)"
    assert_contains "dist=main component=stable bash-tools_1.0.0_all.deb" "$(calls)"
    assert_contains "dist=charm component=stable bash-tools_1.0.0_all.deb" "$(calls)"
}

function test_a_package_missing_from_one_destination_is_published_there_only() {
    printf 'name: bash-tools\narch: all\nversion: 1.0.0\n' >"$PROJECT/packaging/bash-tools.yaml"
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m "route bash-tools"
    git -C "$PROJECT" tag -a v1.2.4 -m "v1.2.4"
    echo 'main stable bash-tools_1.0.0_all.deb' >>"$APT/db/packages.db"
    (cd "$PROJECT" && "$ROOT/bin/apt-package" --publish >/dev/null 2>&1)
    assert_not_contains "dist=main component=stable bash-tools_1.0.0_all.deb" "$(calls)"
    assert_contains "dist=charm component=stable bash-tools_1.0.0_all.deb" "$(calls)"
}

function test_a_package_in_another_component_is_not_treated_as_published() {
    printf 'name: bash-tools\narch: all\nversion: 1.0.0\n' >"$PROJECT/packaging/bash-tools.yaml"
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m "route bash-tools"
    git -C "$PROJECT" tag -a v1.2.4 -m "v1.2.4"
    echo 'main unstable bash-tools_1.0.0_all.deb' >>"$APT/db/packages.db"
    (cd "$PROJECT" && "$ROOT/bin/apt-package" --publish >/dev/null 2>&1)
    assert_contains "dist=main component=stable bash-tools_1.0.0_all.deb" "$(calls)"
    assert_contains "dist=charm component=stable bash-tools_1.0.0_all.deb" "$(calls)"
}

function test_a_prerelease_with_a_stable_only_route_stays_in_its_default_distribution() {
    printf 'name: bash-tools\narch: all\nversion: 1.0.0~beta.1\n' >"$PROJECT/packaging/bash-tools.yaml"
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m "route bash-tools prerelease"
    git -C "$PROJECT" tag -a v1.2.4 -m "v1.2.4"
    export APT_REPO_PRERELEASE_COMPONENT=unstable
    (cd "$PROJECT" && "$ROOT/bin/apt-package" --publish >/dev/null 2>&1)
    assert_contains "dist=main component=unstable bash-tools_1.0.0~beta.1_all.deb" "$(calls)"
    assert_not_contains "dist=charm component=unstable" "$(calls)"
}

function test_tests_option_publishes_untagged_development_packages_to_tests() {
    local out
    printf 'development build\n' >>"$PROJECT/README.md"
    git -C "$PROJECT" commit -q -am "development package"
    export APT_REPO_DIR="$APT"
    out=$(cd "$PROJECT" && "$ROOT/bin/apt-package" --publish --tests 2>&1)
    assert_contains "apt-publish dist=tests component=tests" "$(calls)"
    assert_matches "demo_1.2.3~dev\.[0-9]+\+g[0-9a-f]+_all\.deb" "$(calls)"
    assert_not_contains "gh " "$(calls)"
    assert_not_contains "version tag" "$out"
}

function test_tests_option_requires_publishing() {
    local out
    out=$(cd "$PROJECT" && "$ROOT/bin/apt-package" --tests 2>&1)
    assert_contains "--tests requires --publish" "$out"
}

function test_tests_settings_survive_package_publication() {
    mkdir -p "$PROJECT/tests"
    printf 'APT_REPO_DIR="/project/not-a-repo"\n' >"$PROJECT/.env"
    printf 'APT_REPO_DIR="%s"\nAPT_REPO_TESTS_DIST=tests\nAPT_REPO_TESTS_COMPONENT=tests\n' "$APT" >"$PROJECT/tests/.env"
    unset APT_REPO_DIR
    local status=0 output
    output=$(cd "$PROJECT" && "$ROOT/bin/apt-package" --publish --tests 2>&1) || status=$?
    assert_equals 0 "$status"
    assert_contains 'apt-publish dist=tests component=tests' "$(calls)"
}
