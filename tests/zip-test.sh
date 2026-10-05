#!/usr/bin/env bash
# The zip of a project: made by build-tools, or by the project itself when it has an executable packaging/zip.
#
# Run with: tests/lib/bashunit tests/

source "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

function set_up() {
    new_work
    make_project 1.0.0-dev
}
function tear_down() {
    drop_work
}

function test_the_zip_is_made_from_the_committed_files() {
    (cd "$PROJECT" && "$BT" zip >/dev/null 2>&1)
    assert_file_exists "$PROJECT"/dist/demo-1.0.0-dev.*.zip
    assert_contains "demo/README.md" "$(unzip -l "$PROJECT"/dist/demo-1.0.0-dev.*.zip)"
}

function test_a_project_that_makes_its_zip_itself_does() {
    mkdir -p "$PROJECT/packaging"
    printf '#!/usr/bin/env bash\nmkdir -p dist && echo own >dist/demo-own.zip\n' >"$PROJECT/packaging/zip"
    chmod +x "$PROJECT/packaging/zip"
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m "its own zip"
    (cd "$PROJECT" && "$BT" zip >/dev/null 2>&1)
    assert_file_exists "$PROJECT/dist/demo-own.zip"
    assert_equals "0" "$(ls "$PROJECT"/dist/demo-1.0.0-dev.*.zip 2>/dev/null | wc -l | tr -d ' ')"
}
