# AGENTS.md

`gw` is a zsh CLI for TD gateways. It runs from the clone, so there is no build step.

```zsh
./tests/run           # whole suite, no gateway needed
./tests/run deploy    # tests whose name contains "deploy"
./bin/gw --help
```

Every change comes with a test, and the suite must pass.

## Layout

```
bin/gw                   entry point: loads lib/ and calls gw_main
lib/ui.zsh               palettes (C stdout, E stderr), icons (I), messages, gw_table
lib/runtime.zsh          exit hooks, Ctrl+C, unexpected-failure trap
lib/cli.zsh              command registry, help, argument parsing, "did you mean"
lib/completion.zsh       gw __complete, behind tab completion
lib/config.zsh           line-based files in ~/.config/gw
lib/gateway.zsh          aliases, gateway argument, session fallback
lib/activity.zsh         spinner, steps, gw_remote
lib/status.zsh           status table and states
lib/targets.zsh          target files and their backups during a deploy
lib/commands/<name>.zsh  one file per command, loaded automatically
lib/remote/<name>.sh     POSIX sh scripts run on the gateway
shell/gw.zsh             sourced by ~/.zshrc: gw function, prompt, completion
tests/                   suite, helpers, fake ssh / npm / systemctl
```

## Adding a command

```zsh
gw_command ping \
  summary 'Check that a gateway answers' \
  usage '[gateway]' '' \
  flag '-q --quiet' 'Print nothing, only set the exit code' \
  flag '-c --count <n>' 'How many times to try (default 1)' \
  example 'gw ping alpha'

cmd_ping() {
  gw_parse_arguments ping "$@"
  gw_take_gateway ping
  gw_remote "Connecting to $gw_gateway" ping || exit 1
  gw_has_flag --quiet || gw_ok "$gw_gateway answers"
}

complete_ping() {
  gw_complete_gateway_then '' "$@"
}
```

- A flag with a `<placeholder>` takes a value; read it with `gw_flag_value --count 1` (sets `REPLY`).
- `gw_take_gateway` moves the gateway from `gw_arguments` to `gw_gateway`, or uses the session.
- Add the command to `GW_HELP_GROUPS` in `lib/cli.zsh` and to `README.md`. A test checks both.

## Remote scripts

Call with `gw_remote <label> <script> [args...]`. Output lands in `gw_remote_output`, and errors are already
shown to the user. A script:

- prints results as tab-separated lines on stdout and errors as plain sentences on stderr;
- may print `progress: <text>` on stderr for the spinner;
- uses `${GW_APPS_DIR:-/usr/jrd}` and `${GW_TABLES_DIR:-/media/sdcard/tables}` so tests can redirect them;
- is POSIX sh, no bashisms.

## Rules

- **No comments in code.** A test enforces it.
- **Output:** results go to stdout; messages go to stderr through `gw_ok`, `gw_warn`, `gw_error`, `gw_note`,
  `gw_hint` and `gw_heading`. Use the `C`/`E` colours and `I` icons, never raw escape codes or emojis. Tables
  go through `gw_table`.
- **Errors say what to do next:** `gw_die_with_hint`. Wrong usage goes through `gw_usage_error` (exit 2).
- **Strict mode:** an unhandled failure is reported as a bug. Never call a function that may `gw_die`
  inside `$(...)`.
- **Cleanup:** `gw_on_exit <function>` runs on success, failure and Ctrl+C.
- **`gw session`** prints shell code on stdout, so nothing else may go there.
- **Names:** shared helpers are `gw_*`, helpers for one command are `<command>_*`. Never use `path` or
  `status` as variable names.
- **Examples:** use dummy data only: `alpha` (`td@alpha.local`), `bravo` (`td@bravo.local`) and made-up
  device ids.

## Tests

`tests/run` runs each `test_*` in a sandbox with its own `HOME`, fake repos and fake gateway. In the
sandbox, `ssh` runs remote scripts locally, and any address containing `unreachable` fails. Fixtures
(`given_*`), `run_gw` (fills `gw_stdout`, `gw_stderr`, `gw_exit`) and `assert_*` are in
`tests/helpers.zsh`. Real deploys and restarts aren't covered, so try those on a gateway before you
merge.
