# Development rules

## Build tools

- `bin/`: the commands composer links in `vendor/bin` (`build-tools`, `apt-package`, `apt-publish`)
- `libexec/`: the commands `build-tools` runs (`build`, `release`, `switch`, `stage`, `version`, `zip`)
- `src/lib/helpers`: loads bash-tools and defines `retry`; `src/lib/common`: also finds the project (the git repository the command is run in) and its name
- `dev/`: `build.sh` and `release.sh`, the two commands of this project, run by itself
- `tests/`: [bashunit](https://bashunit.typeddevs.com), `tests/lib/bashunit tests/`; `tests/.env` (git-ignored) has the private words to look for

**Nothing specific to a project, a language or a server**: no host, no path, no repository name, no name of anyone's project in
the code. What varies comes from the `.env` of the project (`.env.example` lists it) or from its own files. The tests check that the host name and the home folder of whoever runs them are not in the repository, and the words of `PRIVATE_WORDS` in `tests/.env` (git-ignored): the list itself must not be in the repository, the rest is discipline.

Commands are often reached through a link (composer `vendor/bin`): find the files of this repository from the real path (`realpath "$0"`), never from the link.

The scripts use the functions of bash-tools (`log`, `success`, `warning`, `die`, `end`, `yesno`, `require`, `usage`, `read_env`) and `retry` (what needs a passphrase can time out): no prompt or message of their own.

## Release

`dev/release.sh`: the tools release themselves with their own command (a zip, no Debian package).

---

## General rules

- Use English for code, comments and documentation, short and generic comments.
- Commit messages: `type(scope): summary`, no `(untested)` once verified.
