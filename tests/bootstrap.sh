#!/usr/bin/env bash
# Loaded by bashunit before the tests.

tests_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# The test environment, from the example on the first run
[[ -f "$tests_dir/.env" ]] || cp "$tests_dir/.env.example" "$tests_dir/.env"

# bashunit reads the .env of the project, the one the commands read for real: nothing of it reaches the tests, each test sets
# what it needs in its own folder
unset APT_REPO_DIR APT_REPO_HOST APT_REPO_PATH APT_REPO_DIST APT_REPO_PRERELEASE_DIST DEB_MAINTAINER DEB_VENDOR DEB_URL \
    RELEASE_REMOTE RELEASE_GITHUB_REPO RELEASE_YES GH APT_PACKAGE APT_PUBLISH BUILD_NAME BUILD_PROJECT SWITCH_WAIT DIRTY
