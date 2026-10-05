## Changelog

### Unreleased

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
