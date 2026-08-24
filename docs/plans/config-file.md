# Plan: Config-file-backed configuration (hybrid with env vars)

## Goal

Read zsh-ai configuration from a plain-text config file at
`~/.config/zsh/zsh-ai` instead of requiring every setting to be an env var.
Keep the existing env var names unchanged; env vars that are already set take
precedence over the file (hybrid approach).

## Motivation

- **Collisions**: env var names like `ANTHROPIC_API_KEY` are shared with other
  tools. A config file namespaces settings by location.
- **Security**: values read from the file are loaded as *non-exported* shell
  parameters, so keys never leak into child process environments.
- **Ergonomics**: one file holds all settings (provider, keys, models, URLs).

## Design

- Path: `${XDG_CONFIG_HOME:-$HOME/.config}/zsh/zsh-ai`, overridable with
  `ZSH_AI_CONFIG` (also the hook tests use to isolate themselves).
- Format: `KEY=VALUE` lines, `#` comments and blank lines ignored, optional
  surrounding quotes on the value stripped, CRLF tolerated.
- Precedence: already-set (non-empty) env var > config file > default in
  `lib/config.zsh`. The file never clobbers a value that is already set.
- Values loaded with `typeset -g KEY=value` (not exported) unless the
  parameter was already exported.

## Files touched

- `lib/config.zsh` — add `_zsh_ai_load_config()` + call it before defaults;
  point validation messages at the config file.
- `tests/test_helper.zsh` — isolate tests from the user's real config file.
- `tests/config.test.zsh` — new tests: file load, env precedence, comments,
  XDG path, missing file.
- Docs: `README.md`, `INSTALL.md`, `TROUBLESHOOTING.md`.

## Out of scope

- Renaming env vars to a `ZSH_AI_` prefix (explicitly deferred by the user).
- Provider modules: unchanged, they already read the resolved variables.
