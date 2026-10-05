## Changelog

### Unreleased

- new: `build-tools build|release|switch|stage|version|zip`, from the scripts the projects copied
- new: `apt-package` and `apt-publish`, out of the apt repository: the repository, the host and the paths are settings
- new: `apt-publish --resume` publishes what a signature that timed out left pending
- new: the pre-releases (`~` in the version) can go to their own suite of the apt repository
- new: a project with no `packaging/*.yaml` is released as a zip alone, with no nfpm and no apt repository
- new: `dev/build.sh` and `dev/release.sh`, the way a project calls build-tools
