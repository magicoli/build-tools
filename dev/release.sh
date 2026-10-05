#!/usr/bin/env bash
# Releases this project, from where it stands to the end (build-tools release)

exec "$(dirname "$0")/../bin/build-tools" release "$@"
