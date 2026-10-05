## Changelog

### Unreleased

- fix: the report of a release lists the packages that carry its version, and says the others may be published too
- fix: a revision of Debian (`0.9.3.0-1`) is no pre-release: its package stays in the suite of the releases

### 0.1.4

- new: an executable `packaging/build-zip` in the project overrides the generic one

### 0.1.2

- fix: a `build/packaging.env` left by a former build no longer gives its version to the package

### 0.1.1

- new: `release patch|minor|major|stable|dev|alpha|beta|rc|X.Y.Z-rung.N`, from the last release
- update: `release` alone is the next patch after a stable version, the next number after a pre-release
- new: `.version` is optional, the version follows the last tag, or composer.json when it is ahead
- update: the packages, the zip and the release have one version, from `build-tools version`
- update: shorter messages
- update: the commit after a release is `dev: bump work version to <version>`
- fix: the builds of a pre-release series come after its last release, not after the next one
- new: `rc` is followed by `rc.2`, `rc3` by `rc4`
- fix: the release asks the passphrase on the terminal, gpg did not find it (Inappropriate ioctl)
- fix: with no terminal, a failed signature stops instead of asking again for ever
- update: the release shows what it will publish in one report, says the next version once it is made
- update: the next version is committed, not pushed, it goes with the next release

### 0.1.0

- new: `build-tools build|release|switch|stage|version|zip`, from the scripts the projects copied
- new: `apt-package` and `apt-publish`, out of the apt repository: the repository, the host and the paths are settings
- new: `apt-publish --resume` publishes what a signature that timed out left pending
- new: the pre-releases (`~` in the version) can go to their own suite of the apt repository
- new: a project with no `packaging/*.yaml` is released as a zip alone, with no nfpm and no apt repository
- new: `dev/build.sh` and `dev/release.sh`, the way a project calls build-tools
