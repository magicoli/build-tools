# Development rules

## Build tools

- `bin/`: the commands composer links in `vendor/bin` (`build-tools`, `apt-package`, `apt-publish`)
- `libexec/`: the commands `build-tools` runs (`build`, `release`, `switch`, `stage`, `version`, `zip`)
- `src/lib/helpers`: loads bash-tools and defines `retry`; `src/lib/common`: also finds the project (the git repository the command is run in) and its name
- `tests/`: [bashunit](https://bashunit.typeddevs.com), `tests/lib/bashunit tests/`

**Nothing specific to a project, a language or a server**: no host, no path, no repository name, no name of anyone's project in
the code. What varies comes from the `.env` of the project (`.env.example` lists it) or from its own files. A test enforces it.

Commands are often reached through a link (composer `vendor/bin`): find the files of this repository from the real path (`realpath "$0"`), never from the link.

The scripts use the functions of bash-tools (`log`, `success`, `warning`, `die`, `end`, `yesno`, `require`, `usage`, `read_env`) and `retry` (what needs a passphrase can time out): no prompt or message of their own.

## Release

`build-tools release`: the tools release themselves with their own command.

---

## General rules

- Use English for code, comments and documentation, short and generic comments.
- Commit messages: `type(scope): summary`, no `(untested)` once verified.
