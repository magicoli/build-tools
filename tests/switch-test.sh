#!/usr/bin/env bash

source "$(dirname "${BASH_SOURCE[0]}")/fixtures.sh"

function set_up() {
    new_work
    make_stubs
    PROJECT="$WORK/project"
    SIBLING="$WORK/build-tools"
    mkdir -p "$PROJECT/packaging" "$SIBLING"
    git init -q -b dev "$PROJECT"
    git -C "$PROJECT" config user.name test
    git -C "$PROJECT" config user.email test@example.test
    git init -q -b dev "$SIBLING"
    git -C "$SIBLING" config user.name test
    git -C "$SIBLING" config user.email test@example.test
    printf '{"name":"example/app","require":{"magicoli/build-tools":"^0.1.11"},"require-dev":{"magicoli/build-tools":"^0.1.11"}}\n' >"$PROJECT/composer.json"
    printf 'magicoli/build-tools build-tools\n' >"$PROJECT/packaging/siblings"
    printf '{"name":"magicoli/build-tools"}\n' >"$SIBLING/composer.json"
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m project
    git -C "$SIBLING" add -A
    git -C "$SIBLING" commit -q -m sibling
    cat >"$WORK/bin/composer" <<'STUB'
#!/usr/bin/env bash
echo "composer $*" >>"$STUB_LOG"
STUB
    chmod +x "$WORK/bin/composer"
}

function tear_down() {
    drop_work
}

function test_dev_switch_removes_duplicate_sibling_from_require_dev() {
    (cd "$PROJECT" && "$BT" switch dev >/dev/null)
    local require require_dev repository
    require=$(php -r 'echo json_decode(file_get_contents($argv[1]))->require->{"magicoli/build-tools"};' "$PROJECT/composer.json")
    require_dev=$(php -r 'echo isset(json_decode(file_get_contents($argv[1]))->{"require-dev"}->{"magicoli/build-tools"}) ? "present" : "absent";' "$PROJECT/composer.json")
    repository=$(php -r 'echo json_decode(file_get_contents($argv[1]))->repositories[0]->url;' "$PROJECT/composer.json")
    assert_equals '@dev' "$require"
    assert_equals 'absent' "$require_dev"
    assert_equals '../build-tools/' "$repository"
    assert_contains 'composer update magicoli/build-tools --no-interaction' "$(calls)"
}
