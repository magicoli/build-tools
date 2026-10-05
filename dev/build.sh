#!/usr/bin/env bash
# Builds the zip into dist/ from the last commit (build-tools build)

exec "$(dirname "$0")/../bin/build-tools" build "$@"
