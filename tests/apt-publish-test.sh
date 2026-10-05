#!/usr/bin/env bash
# apt-publish: the packages are added, the repository is committed, pushed, and the host pulls it; the repository, the host
# and the path are settings; a signature that times out is offered again.
#
# Run with: tests/lib/bashunit tests/

source "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

function set_up() {
    new_work
    make_stubs
    make_apt_repo
    printf 'deb' >"$WORK/demo_1.0.0_all.deb"
}
function tear_down() {
    drop_work
}

function test_it_needs_to_be_told_which_repository() {
    local out
    unset APT_REPO_DIR
    out=$(cd "$WORK" && "$ROOT/bin/apt-publish" demo_1.0.0_all.deb 2>&1)
    assert_contains "APT_REPO_DIR is not set" "$out"
}

function test_it_has_no_host_of_its_own() {
    local out
    : >"$APT/.env"
    out=$(cd "$WORK" && "$ROOT/bin/apt-publish" demo_1.0.0_all.deb 2>&1)
    assert_contains "APT_REPO_HOST is not set" "$out"
}

function test_it_publishes_to_the_host_the_settings_name() {
    (cd "$WORK" && "$ROOT/bin/apt-publish" demo_1.0.0_all.deb >/dev/null 2>&1)
    assert_equals "add demo_1.0.0_all.deb" "$(git -C "$APT" log -1 --format=%s)"
    assert_equals "$(git -C "$APT" rev-parse HEAD)" "$(git -C "$WORK/apt-origin.git" rev-parse main)"
    assert_contains "ssh host.example.test git -C /srv/apt\\ test pull -q --ff-only" "$(calls)"
}

function test_the_repository_env_gives_the_defaults_the_environment_wins() {
    (cd "$WORK" && APT_REPO_HOST=other.example.test "$ROOT/bin/apt-publish" demo_1.0.0_all.deb >/dev/null 2>&1)
    assert_contains "ssh other.example.test" "$(calls)"
}

function test_a_signature_that_times_out_is_offered_again_and_the_publication_goes_on() {
    local status
    export REPREPRO_FAIL_INCLUDE=1 REPREPRO_FAIL_EXPORT=1
    printf 'y\ny\n' | (cd "$WORK" && "$ROOT/bin/apt-publish" demo_1.0.0_all.deb >/dev/null 2>&1)
    status=$?
    assert_equals 0 "$status"
    assert_equals "2" "$(grep -c '^reprepro .* export' "$STUB_LOG")"
    assert_equals "add demo_1.0.0_all.deb" "$(git -C "$APT" log -1 --format=%s)"
    assert_contains "ssh host.example.test" "$(calls)"
}

function test_resume_publishes_what_a_failed_signature_left_pending() {
    # The package is in the pool and the database, nobody committed it
    mkdir -p "$APT/public/pool/main/x"
    printf 'deb' >"$APT/public/pool/main/x/pending_2.0.0_all.deb"
    echo "stable pending_2.0.0_all.deb" >>"$APT/db/packages.db"
    (cd "$WORK" && "$ROOT/bin/apt-publish" --resume >/dev/null 2>&1)
    assert_equals "add pending_2.0.0_all.deb" "$(git -C "$APT" log -1 --format=%s)"
    assert_contains "reprepro -b $APT export" "$(calls)"
    assert_contains "ssh host.example.test" "$(calls)"
    assert_equals "$(git -C "$APT" rev-parse HEAD)" "$(git -C "$WORK/apt-origin.git" rev-parse main)"
}

function test_resume_with_no_package_pending_signs_the_indices_again_and_the_host_pulls() {
    (cd "$WORK" && "$ROOT/bin/apt-publish" --resume >/dev/null 2>&1)
    assert_equals "update the indices" "$(git -C "$APT" log -1 --format=%s)"
    assert_contains "ssh host.example.test" "$(calls)"
}
