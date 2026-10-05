# What the tests share: a project and an apt repository made in a temporary folder, and stand-ins for the programs that
# would reach the network, a key or a repository (gh, gpg, reprepro, ssh, nfpm). Nothing is read or written outside WORK.
# Sourced by the tests, not run.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BT="$ROOT/bin/build-tools"

# The stand-ins write what they are asked to STUB_LOG, and count their calls in STUB_STATE
make_stubs() {
    mkdir -p "$WORK/bin" "$WORK/state"
    export STUB_LOG="$WORK/calls.log" STUB_STATE="$WORK/state"
    : >"$STUB_LOG"

    cat >"$WORK/bin/gh" <<'STUB'
#!/usr/bin/env bash
echo "gh $*" >>"$STUB_LOG"
case "$1 $2" in
    "auth status") exit 0 ;;
    "release view") exit 1 ;;
    "release create") [[ -z "${FAIL_GH_CREATE:-}" ]] || { echo "gh: cannot create the release" >&2; exit 1; } ;;
esac
exit 0
STUB

    # gpg: the first GPG_FAIL_FIRST signatures fail as a passphrase prompt that timed out
    cat >"$WORK/bin/gpg" <<'STUB'
#!/usr/bin/env bash
echo "gpg $*" >>"$STUB_LOG"
n=$(cat "$STUB_STATE/gpg.count" 2>/dev/null || echo 0)
echo $((n + 1)) >"$STUB_STATE/gpg.count"
if [[ $n -lt ${GPG_FAIL_FIRST:-0} ]]; then
    echo "gpg: signing failed: Timeout" >&2
    exit 2
fi
while [[ $# -gt 0 ]]; do
    [[ "$1" != --output ]] || echo signature >"$2"
    shift
done
[[ " $* " != *" --clearsign "* ]] || cat >/dev/null
exit 0
STUB

    # reprepro: includedeb puts the files in the pool and the database; export writes the indices. REPREPRO_FAIL_INCLUDE
    # makes the first includedeb end as a signature that timed out, REPREPRO_FAIL_EXPORT the first exports fail
    cat >"$WORK/bin/reprepro" <<'STUB'
#!/usr/bin/env bash
echo "reprepro $*" >>"$STUB_LOG"
repo=$2
case "$3" in
    includedeb)
        dist=$4
        shift 4
        for deb in "$@"; do
            mkdir -p "$repo/public/pool/main/x"
            cp "$deb" "$repo/public/pool/main/x/"
            echo "$dist $(basename "$deb")" >>"$repo/db/packages.db"
        done
        if [[ -n "${REPREPRO_FAIL_INCLUDE:-}" && ! -f "$STUB_STATE/include.failed" ]]; then
            : >"$STUB_STATE/include.failed"
            echo "gpgme gave error Pinentry:62:  Timeout" >&2
            echo "ERROR: Could not finish exporting '$dist'!" >&2
            exit 1
        fi
        mkdir -p "$repo/public/dists/$dist"
        echo exported >"$repo/public/dists/$dist/Release"
        ;;
    export)
        n=$(cat "$STUB_STATE/export.count" 2>/dev/null || echo 0)
        echo $((n + 1)) >"$STUB_STATE/export.count"
        if [[ $n -lt ${REPREPRO_FAIL_EXPORT:-0} ]]; then
            echo "gpgme gave error Pinentry:62:  Timeout" >&2
            exit 1
        fi
        mkdir -p "$repo/public/dists/stable"
        echo exported >"$repo/public/dists/stable/Release"
        ;;
    list) ;;
esac
exit 0
STUB

    cat >"$WORK/bin/ssh" <<'STUB'
#!/usr/bin/env bash
echo "ssh $*" >>"$STUB_LOG"
STUB

    # nfpm: a package named after the definition, as nfpm prints it
    cat >"$WORK/bin/nfpm" <<'STUB'
#!/usr/bin/env bash
echo "nfpm $*" >>"$STUB_LOG"
config= target=
while [[ $# -gt 0 ]]; do
    case "$1" in --config) config=$2 ;; --target) target=$2 ;; esac
    shift
done
cp "$config" "$STUB_STATE/last-definition.yaml"
name=$(sed -n 's/^name: *//p' "$config" | head -1)
version=$(sed -n 's/^version: *//p' "$config" | head -1 | tr -d '"')
mkdir -p "$target"
printf 'deb' >"$target/${name}_${version}_all.deb"
echo "created package: ${target%/}/${name}_${version}_all.deb"
STUB

    # apt-package, for the release (APT_PACKAGE): it fails the first time when APT_FAIL_ONCE is set
    cat >"$WORK/bin/apt-package-stub" <<'STUB'
#!/usr/bin/env bash
echo "apt-package $*" >>"$STUB_LOG"
if [[ -n "${APT_FAIL_ONCE:-}" && ! -f "$STUB_STATE/apt.failed" ]]; then
    : >"$STUB_STATE/apt.failed"
    echo "gpgme gave error Pinentry:62:  Timeout"
    echo "ERROR: Could not finish exporting 'stable'!"
    exit 1
fi
STUB

    # apt-publish, for apt-package (APT_PUBLISH): it only says with which suite it is called
    cat >"$WORK/bin/apt-publish-stub" <<'STUB'
#!/usr/bin/env bash
echo "apt-publish dist=${APT_REPO_DIST:-} $(basename -a "$@" | tr '\n' ' ')" >>"$STUB_LOG"
STUB
    chmod +x "$WORK"/bin/*
    export PATH="$WORK/bin:$PATH"
}

# An apt repository: a git clone with an origin, conf/distributions, db and public, and settings of its own in its .env
make_apt_repo() {
    APT="$WORK/apt"
    mkdir -p "$APT/conf" "$APT/db" "$APT/public"
    printf 'Codename: stable\nSuite: stable\nSignWith: TESTKEY0001\n\nCodename: unstable\nSuite: unstable\nSignWith: TESTKEY0001\n' >"$APT/conf/distributions"
    printf 'APT_REPO_HOST=host.example.test\nAPT_REPO_PATH="/srv/apt test"\n' >"$APT/.env"
    : >"$APT/db/packages.db"
    git init -q -b main "$APT"
    git -C "$APT" config user.name test
    git -C "$APT" config user.email test@example.test
    printf '.env\n' >"$APT/.gitignore"
    git -C "$APT" add -A
    git -C "$APT" commit -q -m "the repository"
    git init -q --bare "$WORK/apt-origin.git"
    git -C "$APT" remote add origin "$WORK/apt-origin.git"
    git -C "$APT" push -q origin main
    git -C "$APT" branch -q --set-upstream-to=origin/main main
    export APT_REPO_DIR="$APT"
}

# A project: a git repository with a changelog, a version, a remote called github
make_project() { # version
    PROJECT="$WORK/project"
    mkdir -p "$PROJECT"
    git init -q -b dev "$PROJECT"
    git -C "$PROJECT" config user.name test
    git -C "$PROJECT" config user.email test@example.test
    printf '%s\n' "${1:-1.0.0-dev}" >"$PROJECT/.version"
    printf '## Changelog\n\n### Unreleased\n\n- new: the first thing\n- fix: the second thing, `with code`\n\n- update: after a blank line\n' >"$PROJECT/CHANGELOG.md"
    printf 'hello\n' >"$PROJECT/README.md"
    printf 'dist/\nbuild/\ntmp/\n.env\n' >"$PROJECT/.gitignore"
    git -C "$PROJECT" add -A
    git -C "$PROJECT" commit -q -m "the project"
    git init -q --bare "$WORK/github.git"
    git -C "$PROJECT" remote add github "$WORK/github.git"
    export BUILD_NAME=demo RELEASE_GITHUB_REPO=owner/demo RELEASE_YES=1 APT_PACKAGE="$WORK/bin/apt-package-stub"
}

new_work() {
    WORK=$(mktemp -d "${TMPDIR:-/tmp}/build-tools-test.XXXXXX")
    export HOME_TEST="$WORK"
}
drop_work() {
    rm -rf "$WORK"
    unset STUB_LOG STUB_STATE APT_REPO_DIR BUILD_NAME RELEASE_GITHUB_REPO RELEASE_YES APT_PACKAGE APT_PUBLISH \
        FAIL_GH_CREATE GPG_FAIL_FIRST REPREPRO_FAIL_INCLUDE REPREPRO_FAIL_EXPORT APT_FAIL_ONCE APT_REPO_PRERELEASE_DIST APT_REPO_DIST \
        APT_REPO_HOST APT_REPO_PATH
}

# The calls the stand-ins recorded
calls() {
    cat "$STUB_LOG"
}
