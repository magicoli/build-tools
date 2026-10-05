#!/usr/bin/env bash
# What belongs to nobody else stays out of the repository: the host name and the home folder of whoever runs the tests, and
# the words tests/.env lists. That list is private, so it is not in the repository either (tests/.env is git-ignored):
#   PRIVATE_WORDS   words that must not appear anywhere in the files of the repository
#   PRIVATE_SKIP    files where some of them are meant to be (e.g. composer.json for the name of its author)
# Anything else is discipline.
#
# Run with: tests/lib/bashunit tests/

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# A setting of tests/.env, else of the environment
private_setting() { # name
    (
        set +u
        [[ ! -f "$ROOT/tests/.env" ]] || . "$ROOT/tests/.env" >/dev/null 2>&1
        printf '%s' "${!1:-}"
    )
}

# The files of the repository, tracked or not yet, without bashunit and the files PRIVATE_SKIP names
repo_files() {
    local skip file
    skip=$(private_setting PRIVATE_SKIP)
    while IFS= read -r file; do
        [[ " $skip " == *" $file "* ]] || echo "$file"
    done < <(git -C "$ROOT" ls-files -co --exclude-standard | grep -v '^tests/lib/')
}

# Where the words are found, as file:line
find_in_repo() { # grep options, word
    local file
    while IFS= read -r file; do
        (cd "$ROOT" && grep -nI "$1" -e "$2" -- "$file" | sed "s#^#$file:#")
    done < <(repo_files)
}

function test_the_host_name_of_the_machine_is_not_in_the_repository() {
    local name found=
    for name in "$(hostname)" "$(hostname -s)"; do
        # a short name or localhost would match any text
        [[ ${#name} -ge 3 && $name != localhost ]] || continue
        found+=$(find_in_repo -Fiw "$name")
    done
    assert_equals "" "$found"
}

function test_the_home_folder_is_not_in_the_repository() {
    assert_equals "" "$(find_in_repo -F "$HOME")"
}

function test_the_words_of_the_private_list_are_not_in_the_repository() {
    local word found=
    for word in $(private_setting PRIVATE_WORDS); do
        found+=$(find_in_repo -Fiw "$word")
    done
    assert_equals "" "$found"
}

function test_the_examples_use_names_that_belong_to_nobody() {
    local found
    found=$(grep -nE '^[A-Z_]+=' "$ROOT/.env.example" | grep -E 'HOST|PATH|DIR' | grep -vE 'example|/path/to|/var/www' || true)
    assert_equals "" "$found"
}
