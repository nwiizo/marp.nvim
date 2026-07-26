# marp.nvim repository guide

## Scope

marp.nvim integrates Neovim 0.10+ with Marp CLI v4. Keep changes focused on
editing, previewing, process lifecycle, config discovery, and export behavior.
Do not reimplement presentation features already provided by Marp's templates.

## Source of truth

- `lua/marp.lua`: user-facing setup and actions
- `lua/marp/cli.lua`: Marp config discovery and argv construction
- `lua/marp/health.lua`: `:checkhealth marp`
- `plugin/marp.lua`: small, lazy command entrypoint
- `tests/marp_cli_spec.lua`: fast tests without an external Marp process
- `tests/marp_integration.lua`: integration tests against an installed `marp`
- `README.md`: user-facing installation, commands, and configuration
- `doc/marp.txt`: `:help marp`

`plugin/marp.lua` must not eagerly require the main module. Add commands with
Lua callbacks, descriptions, and completion through
`nvim_create_user_command()`.

When a public setup option changes, update its default, both README language
sections, and `doc/marp.txt` in the same change.

## Process and compatibility rules

- Target Neovim 0.10 or newer.
- Execute Marp through `vim.system()` with an argv list; do not build shell
  command strings.
- Keep `marp_command` string compatibility, but document argv lists as the
  preferred form for commands with arguments.
- File-based Marp invocations must include `--no-stdin` by default. Neovim's
  non-TTY stdin behavior can otherwise make Marp wait for EOF.
- Keep long-running watch/server handles in `M.active_processes` and stop them
  on buffer cleanup and `VimLeavePre`.
- Marp server mode accepts a directory, not a Markdown file.
- Keep `allow_local_files = false` as the secure default.
- Match Marp CLI's cosmiconfig search places when changing config discovery.

## Validation

Run these before reporting completion:

```sh
make check
make test
make integration
nvim --headless -u minimal_init.lua \
  -c "checkhealth marp" \
  -c "qa!"
```

`make integration` requires Marp CLI and starts a temporary local server.

After changing `doc/marp.txt`, regenerate help tags:

```sh
nvim --headless -u NONE \
  -c "helptags doc" \
  -c "qa!"
```

Preserve unrelated working-tree changes. Do not commit generated presentation
outputs or machine-local paths.
