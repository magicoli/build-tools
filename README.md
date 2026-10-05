# Build tools

Build, release and publish a project, the same way for every one: the Debian packages (nfpm), the zip, the tag, the GitHub
release, the apt repository. Nothing here is specific to a project, a language or a server: what a project needs to say is
in its own files, and where it publishes is in its `.env`.

## Install

In a project (a git repository), as a development dependency:

```bash
composer require --dev magicoli/build-tools
vendor/bin/build-tools
```

It brings [bash-tools](https://github.com/magicoli/bash-tools), whose functions every script uses to ask, tell and fail.

## Commands

| Command                           | What it does                                                                                                                        |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| `build-tools build [deb\|zip]`    | the packages and the zip of the last commit, into `dist/` (refuses uncommitted changes and a stale `composer.lock`, `DIRTY=1` to go on) |
| `build-tools release [VERSION]`   | the whole release, from where it stands: release commit, tag, push, packages, publication, GitHub release, next version              |
| `build-tools release status`      | what is done and what remains                                                                                                       |
| `build-tools switch dev\|release` | the projects of the family linked next to this one (dev), or required by version from Packagist (release)                           |
| `build-tools stage DIR deb\|zip`  | the files a package or a zip holds, in DIR                                                                                          |
| `build-tools version`             | the version of this build, as `VERSION=` and `DEB_VERSION=` lines                                                                    |
| `apt-package [--publish]`         | builds the Debian packages of `packaging/*.yaml` and publishes them                                                                  |
| `apt-publish PACKAGE.deb…`        | adds packages to an apt repository and publishes it; `--resume` publishes what a failed signature left pending                       |

### In a project

A project keeps two small scripts where one looks for them, `dev/build.sh` and `dev/release.sh`, that call the commands of its `vendor` folder:

```bash
#!/usr/bin/env bash
tool="$(dirname "$0")/../vendor/bin/build-tools"
[[ -x "$tool" ]] || { echo "build-tools is not installed: composer install" >&2; exit 1; }
exec "$tool" release "$@"
```

(`build` for `dev/build.sh`, `switch` for `dev/switch.sh` in a project that requires others of its family.) This project has the same two, calling its own `bin/build-tools`.

## What a project provides

- `.version` (optional): the version in progress (`1.2.3-beta.1`, `1.2.3-dev`). Without it, the version of `composer.json` when it is ahead of the last tag, else the one after the last tag (`1.0.7` then `1.0.8-dev`, `3.0.0-beta.4` then `3.0.0-beta.5`). The tag of a release is the version.
- `CHANGELOG.md`: sections `### Unreleased` then `### <version>`. The release commit and the tag are `v<version>` followed by the lines of the section, verbatim.
- `packaging/<package>.yaml`: nfpm definitions, `${VERSION}` and `${DEB_VERSION}` are expanded. An executable `packaging/build` may prepare what they install, and an executable `packaging/zip` makes the zip instead of build-tools.
- `.distignore`: what git tracks and the packages and the zip do not hold (rsync style, `/name` at the root).
- Without `packaging/*.yaml`, the project is released as a zip alone: no nfpm, no apt repository.
- `packaging/siblings`: the projects of the family the Debian package gets from their own packages (composer name, package).

## Versions

`build-tools release WHAT` takes the version from the last release (the last version tag):

| WHAT | Version |
| --- | --- |
| (nothing) | after a stable version, the next patch; after a pre-release, the next number of its series (`3.0.0-beta.4`, `3.0.0-beta.5`) |
| `stable` | the stable version of a pre-release (`3.0.0-rc.2`, `3.0.0`), else the next patch |
| `patch`, `minor`, `major` | a bump of the last release |
| `dev`, `alpha`, `beta`, `rc` | the next number of the series; the first one (`.1`) on the same version when it is above the last release, on the next patch when it is not |
| `1.2.3-beta.4` | that version, which must be above the last release |

The rungs, from the lowest: `dev`, `alpha`, `beta`, `rc`, stable. Only a stable release moves to the next patch. Pre-releases are GitHub pre-releases, and go to `APT_REPO_PRERELEASE_DIST` when the apt repository has that suite. The first release of a project is its version in progress (`.version`, `composer.json`), or the one given.

Debian sorts the names of the rungs alphabetically, as semver does: `alpha` < `beta` < `dev` < `rc`. A `dev` version sorts above `alpha` and `beta` of the same number in apt. Number the series the same way (`rc.1`, `rc.2`): `rc3` sorts before `rc.2`.

## Settings

Everything comes from the `.env` of the project (git-ignored), see `.env.example`. There is no default host, no default path and
no default repository: a project that publishes says where, and different projects publish to different repositories.

| Variable                   | Meaning                                                                                       |
| -------------------------- | --------------------------------------------------------------------------------------------- |
| `APT_REPO_DIR`             | the local clone of the apt repository (`conf/distributions`, `db`, `public`)                  |
| `APT_REPO_HOST`            | the ssh host serving it                                                                       |
| `APT_REPO_PATH`            | its clone on that host                                                                        |
| `APT_REPO_DIST`            | the suite of the releases (default `stable`)                                                  |
| `APT_REPO_PRERELEASE_DIST` | the suite of the pre-releases, the versions with a `~` (default: the same as the releases)    |
| `DEB_MAINTAINER`, `DEB_VENDOR`, `DEB_URL` | the fields a package definition leaves out                                     |
| `RELEASE_REMOTE`           | the remote tags and releases are pushed to (default `github`)                                 |

The host, the path and the suites can also be in the `.env` of the apt repository itself, shared by the projects that publish to
it; the one of the project wins.

A release shows what it will publish (tag, message, assets, publication) and asks one question, one key. It then asks the
passphrase of the key, before anything is pushed; when a prompt times out because nobody was there, the failure is said and
trying again is offered (with no terminal to answer, it stops). The next development version is committed, not pushed: it goes
with the next release.

## Tests

`tests/lib/bashunit tests/`. The tests run in temporary folders, with stand-ins for `gh`, `gpg`, `reprepro`, `ssh` and `nfpm`: nothing is published, nothing leaves the machine.

They check that the host name and the home folder of whoever runs them are not in the repository, and the words of `PRIVATE_WORDS` in `tests/.env` (git-ignored, created from `tests/.env.example`, with `PRIVATE_SKIP` for the files where they belong). The list of private words is not in the repository itself; the rest is discipline.
