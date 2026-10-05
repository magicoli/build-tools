#!/usr/bin/env bash
# The passphrase prompt of gpg needs the terminal: GPG_TTY is set when the input is a terminal (gpg cannot find it
# when its input is a pipe), and the suite of a version follows the settings of the repository.
#
# Run with: tests/lib/bashunit tests/

source "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

function set_up() {
    new_work
    make_apt_repo
}
function tear_down() {
    drop_work
}

# The output of a script run on a pseudo-terminal
on_terminal() { # script
    python3 - "$1" <<'PY'
import os, pty, select, sys, time
pid, fd = pty.fork()
if pid == 0:
    env = {k: v for k, v in os.environ.items() if k != 'GPG_TTY'}
    os.execvpe('bash', ['bash', '-c', sys.argv[1]], env)
out, end = b'', time.time() + 10
while time.time() < end:
    if select.select([fd], [], [], 0.2)[0]:
        try:
            data = os.read(fd, 4096)
        except OSError:
            break
        if not data:
            break
        out += data
os.waitpid(pid, 0)
print(out.decode(errors='replace').replace('\r', '').strip())
PY
}

function test_gpg_tty_is_the_terminal_when_the_input_is_one() {
    assert_matches "^GPG_TTY=/dev/" "$(on_terminal "source '$ROOT/src/lib/helpers'; echo GPG_TTY=\$GPG_TTY")"
}

function test_gpg_tty_is_not_set_without_a_terminal() {
    assert_equals "GPG_TTY=" "$(env -u GPG_TTY bash -c "source '$ROOT/src/lib/helpers'; echo GPG_TTY=\$GPG_TTY" </dev/null)"
}

function test_a_setting_comes_from_the_environment_else_from_the_repository() {
    export APT_REPO_DIR="$APT"
    assert_equals "host.example.test" "$(bash -c "source '$ROOT/src/lib/helpers'; apt_setting APT_REPO_HOST" </dev/null)"
    assert_equals "other.example.test" "$(APT_REPO_HOST=other.example.test bash -c "source '$ROOT/src/lib/helpers'; apt_setting APT_REPO_HOST" </dev/null)"
}

function test_the_prereleases_go_to_their_suite_when_the_repository_has_one() {
    export APT_REPO_DIR="$APT"
    assert_equals "stable" "$(bash -c "source '$ROOT/src/lib/helpers'; apt_dist_of 1.2.3" </dev/null)"
    assert_equals "stable" "$(bash -c "source '$ROOT/src/lib/helpers'; apt_dist_of 1.2.3-beta.1" </dev/null)"
    assert_equals "unstable" "$(APT_REPO_PRERELEASE_DIST=unstable bash -c "source '$ROOT/src/lib/helpers'; apt_dist_of 1.2.3~beta.1" </dev/null)"
    assert_equals "unstable" "$(APT_REPO_PRERELEASE_DIST=unstable bash -c "source '$ROOT/src/lib/helpers'; apt_dist_of 1.2.3-beta.1" </dev/null)"
    assert_equals "stable" "$(APT_REPO_PRERELEASE_DIST=unstable bash -c "source '$ROOT/src/lib/helpers'; apt_dist_of 1.2.3" </dev/null)"
}

function test_a_pre_release_stays_in_its_series_and_a_stable_one_moves_on() {
    local version next
    for version in 3.0.0-beta.4:3.0.0-beta.5 3.0.0-alpha.1:3.0.0-alpha.2 3.0.0-rc:3.0.0-rc.2 3.0.0-rc.2:3.0.0-rc.3 3.0.0-rc3:3.0.0-rc4 3.0.0:3.0.1-dev 1.1.2:1.1.3-dev; do
        next=$(bash -c "source '$ROOT/src/lib/version'; next_version ${version%%:*}")
        assert_equals "${version##*:}" "$next"
    done
}

# What a release gives, from the last release and what is asked: cases written as "asked|last|result"
function test_what_a_release_gives_follows_the_rungs() {
    local case asked last result
    for case in \
        "|1.0.7|1.0.8" "|3.0.0-beta.4|3.0.0-beta.5" "|3.0.0-rc|3.0.0-rc.2" \
        "stable|3.0.0-rc.2|3.0.0" "stable|1.0.7|1.0.8" \
        "patch|1.0.7|1.0.8" "minor|1.0.7|1.1.0" "major|1.0.7|2.0.0" "patch|3.0.0-beta.4|3.0.1" \
        "beta|3.0.0-beta.4|3.0.0-beta.5" "rc|3.0.0-beta.4|3.0.0-rc.1" "beta|3.0.0-rc.2|3.0.1-beta.1" \
        "alpha|1.0.7|1.0.8-alpha.1" "dev|3.0.0-dev.1|3.0.0-dev.2" "dev|3.0.0-alpha.1|3.0.1-dev.1" \
        "3.0.0-rc.1|3.0.0-beta.4|3.0.0-rc.1" "3.0.0|3.0.0-rc.2|3.0.0" "4.0.0|3.0.0|4.0.0"; do
        IFS='|' read -r asked last result <<<"$case"
        assert_equals "$result" "$(bash -c "source '$ROOT/src/lib/version'; release_version '$asked' '$last'")"
    done
}

function test_a_version_that_is_not_above_the_last_release_is_refused() {
    local out
    for case in "3.0.0-beta.1|3.0.0-beta.4" "2.9.9|3.0.0" "3.0.0|3.0.0" "3.0.0-rc.1|3.0.0"; do
        out=$(bash -c "source '$ROOT/src/lib/version'; release_version '${case%%|*}' '${case##*|}'" 2>&1) && fail "${case%%|*} after ${case##*|} was accepted"
        assert_contains "is not above" "$out"
    done
}

function test_what_is_not_a_version_nor_a_word_of_the_rungs_is_refused() {
    local out
    out=$(bash -c "source '$ROOT/src/lib/version'; release_version nonsense 1.0.0" 2>&1) && fail "accepted"
    assert_contains "patch|minor|major|stable|dev|alpha|beta|rc" "$out"
}
