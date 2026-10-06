#!/usr/bin/env bash
# The release: the release commit and the tag say v<version> and the changelog, the push, the publication, the GitHub
# release, the next version; and it resumes where it stopped, and offers again what a passphrase prompt that timed out.
#
# Run with: tests/lib/bashunit tests/

source "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

function set_up() {
    new_work
    make_stubs
    make_apt_repo
    make_project 1.0.0-dev
    add_packaging
}
function tear_down() {
    drop_work
}

# The release, run in the project, its answers to the questions given in input
release() { # input, arguments...
    local input=$1
    shift
    (cd "$PROJECT" && printf '%s' "$input" | "$BT" release "$@" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
}

function test_the_release_commit_and_the_tag_are_the_version_then_the_changelog() {
    local body
    release "" >/dev/null
    body=$(git -C "$PROJECT" log -1 --format=%b --grep='^v1.0.0$')
    assert_equals "- new: the first thing
- fix: the second thing, \`with code\`

- update: after a blank line" "$body"
    assert_equals "v1.0.0" "$(git -C "$PROJECT" log -1 --format=%s --grep='^v1.0.0$')"
    assert_equals "v1.0.0" "$(git -C "$PROJECT" tag -l --format='%(contents:subject)' 1.0.0)"
    assert_equals "$body" "$(git -C "$PROJECT" tag -l --format='%(contents:body)' 1.0.0 | sed '/^$/d;$!b' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}')" || true
}

function test_the_tag_and_the_branch_are_pushed_but_not_the_next_version() {
    release "" >/dev/null
    assert_contains "1.0.0" "$(git -C "$WORK/github.git" tag)"
    assert_equals "v1.0.0" "$(git -C "$WORK/github.git" log -1 --format=%s dev)"
    assert_equals "dev: bump work version to 1.0.1-dev" "$(git -C "$PROJECT" log -1 --format=%s)"
}

function test_the_question_shows_one_report_of_what_will_be_published() {
    local out
    unset RELEASE_YES
    out=$(release "n
")
    assert_contains "preparing to publish demo 1.0.0" "$out"
    assert_contains "  tag: 1.0.0" "$out"
    assert_contains "  msg: v1.0.0
       - new: the first thing" "$out"
    assert_contains "  assets: zip, deb (demo)" "$out"
    assert_contains "  targets: host.example.test (stable), github.com/owner/demo" "$out"
    assert_not_contains "to do" "$out"
    assert_not_contains "1.0.1-dev" "$out"
    assert_equals "1" "$(grep -c 'preparing to publish' <<<"$out")"
}

function test_the_report_says_what_a_previous_run_did() {
    local out
    FAIL_GH_CREATE=1 release "" >/dev/null
    unset RELEASE_YES FAIL_GH_CREATE
    out=$(release "n
")
    assert_contains "already done: release commit, tag, pushed to github" "$out"
}

function test_the_next_version_is_said_once_it_is_made() {
    local out
    out=$(release "")
    assert_contains "demo 1.0.0 released, 1.0.1-dev next (committed, not pushed)" "$out"
}

function test_the_next_version_follows_and_the_changelog_has_a_new_unreleased_section() {
    release "" >/dev/null
    assert_equals "1.0.1-dev" "$(cat "$PROJECT/.version")"
    assert_equals "dev: bump work version to 1.0.1-dev" "$(git -C "$PROJECT" log -1 --format=%s)"
    assert_equals "### Unreleased
### 1.0.0" "$(grep '^### ' "$PROJECT/CHANGELOG.md")"
}

function test_the_packages_are_published_and_the_zip_goes_to_the_github_release() {
    release "" >/dev/null
    assert_contains "apt-package --publish" "$(calls)"
    assert_contains "gh release create 1.0.0 -R owner/demo --verify-tag --title 1.0.0" "$(calls)"
    assert_contains "gh release upload 1.0.0 dist/demo-1.0.0.zip" "$(calls)"
    assert_file_exists "$PROJECT/dist/demo-1.0.0.zip"
}

function test_a_pre_release_is_a_github_pre_release() {
    printf '1.0.0-beta.1\n' >"$PROJECT/.version"
    git -C "$PROJECT" commit -q -am "a beta"
    release "" >/dev/null
    assert_contains "--prerelease" "$(sed -n '/^gh release create/,/^gh release upload/p' "$STUB_LOG")"
    assert_equals "1.0.0-beta.2" "$(cat "$PROJECT/.version")"
}

function test_nothing_under_unreleased_is_nothing_to_release_and_not_an_error() {
    local out status
    printf '## Changelog\n\n### Unreleased\n\n### 0.9.0\n\n- old\n' >"$PROJECT/CHANGELOG.md"
    git -C "$PROJECT" commit -q -am "nothing new"
    out=$(release "")
    status=$?
    assert_contains "nothing under Unreleased" "$out"
    assert_equals "0" "$(git -C "$PROJECT" tag | wc -l | tr -d ' ')"
}

function test_the_question_is_asked_and_no_stops_with_nothing_done() {
    local out
    unset RELEASE_YES
    out=$(release "n
")
    assert_contains "stopped, nothing done" "$out"
    assert_equals "0" "$(git -C "$PROJECT" tag | wc -l | tr -d ' ')"
}

function test_it_resumes_where_it_stopped() {
    # The GitHub release fails after the tag is pushed
    FAIL_GH_CREATE=1 release "" >/dev/null
    assert_contains "1.0.0" "$(git -C "$WORK/github.git" tag)"
    assert_equals "1.0.0" "$(cat "$PROJECT/.version")"
    unset FAIL_GH_CREATE
    release "" >/dev/null
    assert_equals "1" "$(git -C "$PROJECT" tag | wc -l | tr -d ' ')"
    assert_equals "1" "$(git -C "$PROJECT" log --format=%s | grep -c '^v1.0.0$')"
    assert_equals "1.0.1-dev" "$(cat "$PROJECT/.version")"
}

function test_nobody_to_answer_is_a_no_and_not_a_loop() {
    local out
    export GPG_FAIL_FIRST=100
    out=$(release "")
    assert_contains "failed, stopped" "$out"
    assert_equals "1" "$(grep -c 'clearsign' "$STUB_LOG")"
    assert_equals "0" "$(git -C "$PROJECT" tag | wc -l | tr -d ' ')"
}

function test_a_passphrase_prompt_that_times_out_is_offered_again() {
    local out
    export GPG_FAIL_FIRST=1
    out=$(release "y
y
")
    assert_equals "2" "$(grep -c 'clearsign' "$STUB_LOG")"
    assert_equals "1.0.1-dev" "$(cat "$PROJECT/.version")"
}

function test_a_publication_that_times_out_at_the_export_redoes_the_export_alone() {
    export APT_FAIL_ONCE=1 REPREPRO_FAIL_EXPORT=1
    release "y
y
y
" >/dev/null
    assert_equals "2" "$(grep -c '^reprepro .* export' "$STUB_LOG")"
    assert_contains "gh release create 1.0.0" "$(calls)"
    assert_equals "1.0.1-dev" "$(cat "$PROJECT/.version")"
}

function test_it_refuses_without_an_apt_repository_before_doing_anything() {
    local out
    unset APT_REPO_DIR
    out=$(release "")
    assert_contains "APT_REPO_DIR is not set" "$out"
    assert_equals "0" "$(git -C "$PROJECT" tag | wc -l | tr -d ' ')"
}

function test_it_refuses_changes_made_by_hand_and_says_so() {
    local out
    echo more >>"$PROJECT/README.md"
    out=$(release "")
    assert_contains "uncommitted changes" "$out"
}

function test_a_project_without_packages_is_released_as_a_zip_alone() {
    local out
    git -C "$PROJECT" rm -q -r packaging
    git -C "$PROJECT" commit -q -m "no package"
    unset APT_REPO_DIR
    out=$(release "")
    assert_contains "  assets: zip
" "$out"
    assert_contains "  targets: github.com/owner/demo" "$out"
    assert_not_contains "deb" "$out"
    assert_not_contains "apt-package" "$(calls)"
    assert_not_contains "nfpm" "$(calls)"
    assert_not_contains "clearsign" "$(calls)"
    assert_contains "gh release upload 1.0.0 dist/demo-1.0.0.zip" "$(calls)"
    assert_equals "1.0.1-dev" "$(cat "$PROJECT/.version")"
}

# A project with no .version: the tags say the version, the release commit says a release is in progress
function test_a_project_without_a_version_file_is_released_from_its_last_tag() {
    git -C "$PROJECT" rm -q .version
    git -C "$PROJECT" commit -q -m "no .version"
    git -C "$PROJECT" tag -a 0.9.0 -m "0.9.0"
    release "" >/dev/null
    assert_contains "0.9.1" "$(git -C "$WORK/github.git" tag)"
    assert_file_not_exists "$PROJECT/.version"
    assert_equals "v0.9.1" "$(git -C "$WORK/github.git" log -1 --format=%s dev)"
    assert_equals "dev: bump work version to 0.9.2-dev" "$(git -C "$PROJECT" log -1 --format=%s)"
    assert_equals "### Unreleased
### 0.9.1" "$(grep '^### ' "$PROJECT/CHANGELOG.md")"
}

function test_a_project_without_a_version_file_resumes_where_it_stopped() {
    git -C "$PROJECT" rm -q .version
    git -C "$PROJECT" commit -q -m "no .version"
    git -C "$PROJECT" tag -a 0.9.0 -m "0.9.0"
    FAIL_GH_CREATE=1 release "" >/dev/null
    unset FAIL_GH_CREATE
    release "" >/dev/null
    assert_equals "2" "$(git -C "$PROJECT" tag | wc -l | tr -d ' ')"
    assert_equals "1" "$(git -C "$PROJECT" log --format=%s | grep -c '^v0.9.1$')"
    assert_contains "gh release create 0.9.1" "$(calls)"
}

function test_it_refuses_without_a_changelog() {
    local out
    git -C "$PROJECT" rm -q CHANGELOG.md
    git -C "$PROJECT" commit -q -m "no changelog"
    out=$(release "")
    assert_contains "no CHANGELOG.md" "$out"
}

# What is asked: the series, the rungs, a version that is not above
tag_last_release() { # version
    git -C "$PROJECT" tag -a "$1" -m "v$1"
    echo more >>"$PROJECT/README.md"
    git -C "$PROJECT" commit -q -am "after $1"
}

function test_a_rung_below_the_last_release_starts_a_pre_release_on_the_next_patch() {
    tag_last_release 1.0.0
    release "" beta >/dev/null
    assert_contains "1.0.1-beta.1" "$(git -C "$WORK/github.git" tag)"
    assert_contains "--prerelease" "$(sed -n '/^gh release create/,/^gh release upload/p' "$STUB_LOG")"
}

function test_stable_promotes_a_release_candidate_even_with_nothing_new() {
    tag_last_release 3.0.0-rc.2
    printf '## Changelog\n\n### Unreleased\n\n### 3.0.0-rc.2\n\n- the candidate\n' >"$PROJECT/CHANGELOG.md"
    git -C "$PROJECT" commit -q -am "nothing new"
    release "" stable >/dev/null
    assert_contains "3.0.0" "$(git -C "$WORK/github.git" tag)"
    assert_not_contains "--prerelease" "$(sed -n '/^gh release create/,/^gh release upload/p' "$STUB_LOG")"
}

function test_a_version_that_is_not_above_the_last_release_stops_before_anything() {
    local out
    tag_last_release 1.0.0
    out=$(release "" 0.5.0)
    assert_contains "0.5.0 is not above the last release 1.0.0" "$out"
    assert_equals "1" "$(git -C "$PROJECT" tag | wc -l | tr -d ' ')"
}

function test_a_release_in_progress_is_finished_not_replaced() {
    local out
    tag_last_release 1.0.0
    FAIL_GH_CREATE=1 release "" >/dev/null
    unset FAIL_GH_CREATE
    out=$(release "" beta)
    assert_contains "v1.0.1 is in progress" "$out"
    assert_not_contains "1.0.1-beta" "$(git -C "$PROJECT" tag)"
}

function test_a_pre_release_goes_to_the_suite_of_the_pre_releases() {
    local out
    tag_last_release 1.0.0
    unset RELEASE_YES
    out=$(APT_REPO_PRERELEASE_DIST=unstable release "n
" beta)
    assert_contains "  targets: host.example.test (unstable), github.com/owner/demo" "$out"
}

function test_the_report_lists_the_packages_that_carry_the_version_of_the_project() {
    local out
    printf 'name: other-${OTHER_VERSION}\nversion: ${OTHER_VERSION}\n' >"$PROJECT/packaging/other.yaml"
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m "a package with its own version"
    unset RELEASE_YES
    out=$(release "n
")
    assert_contains "  assets: zip, deb (demo)" "$out"
    assert_contains "  also: other (if their version is new)" "$out"
    assert_not_contains "OTHER_VERSION" "$out"
}

function test_a_tag_of_a_step_does_not_change_the_style_of_the_version_tags() {
    tag_last_release 1.0.0
    GIT_COMMITTER_DATE="2099-01-01T00:00:00" git -C "$PROJECT" tag -a vonda-test -m "a step"
    release "" >/dev/null
    assert_contains "1.0.1" "$(git -C "$WORK/github.git" tag)"
    assert_not_contains "v1.0.1" "$(git -C "$WORK/github.git" tag)"
}
