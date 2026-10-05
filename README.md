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

## What a project provides

- `.version`: the version being worked on (`1.2.3-beta.1`, `1.2.3-dev`); the tag of a release is the version.
- `CHANGELOG.md`: sections `### Unreleased` then `### <version>`. The release commit and the tag are `v<version>` followed by the lines of the section, verbatim.
- `packaging/<package>.yaml`: nfpm definitions, `${VERSION}` and `${DEB_VERSION}` are expanded. An executable `packaging/build` may prepare what they install.
- `.distignore`: what git tracks and the packages and the zip do not hold (rsync style, `/name` at the root).
- `packaging/siblings`: the projects of the family the Debian package gets from their own packages (composer name, package).

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

A release asks one question, then signs: the passphrase of the key is asked first, and when a prompt times out because nobody
was there, the failure is said and trying again is offered.
