test_session_start_prints_exports_for_the_shell() {
  given_alias alpha td@alpha.local
  run_gw session alpha
  assert_exit 0
  assert_contains "$gw_stdout" 'export GW_SESSION=td@alpha.local'
  assert_contains "$gw_stdout" 'export GW_SESSION_LABEL=alpha'
  assert_contains "$gw_stderr" 'Session: alpha → td@alpha.local'
}

test_session_works_without_any_targets_configured() {
  run_gw session td@bravo.local
  assert_exit 0
  assert_contains "$gw_stdout" 'export GW_SESSION=td@bravo.local'
}

test_session_exports_env_targets_and_can_be_limited_by_name() {
  given_alias alpha td@alpha.local
  print -r -- $'frontend ~/repos/frontend/.env VITE_PROXY_TARGET\nrest ~/repos/rest/scripts/target' > "$(config_file targets)"

  run_gw session alpha
  assert_contains "$gw_stdout" 'export VITE_PROXY_TARGET=http://td@alpha.local'
  assert_contains "$gw_stdout" 'export GW_SESSION_ENV_VARS=VITE_PROXY_TARGET'

  run_gw session alpha rest
  assert_lacks "$gw_stdout" 'export VITE_PROXY_TARGET'
  assert_contains "$gw_stdout" 'export GW_SESSION_NAMES=rest'
}

test_session_stdout_is_valid_shell_that_sets_and_clears_the_session() {
  given_alias alpha td@alpha.local
  print -r -- 'frontend ~/repos/frontend/.env VITE_PROXY_TARGET' > "$(config_file targets)"

  run_gw session alpha
  eval "$gw_stdout"
  assert_equals 'td@alpha.local' "$GW_SESSION"
  assert_equals 'http://td@alpha.local' "$VITE_PROXY_TARGET"

  run_gw session off
  assert_exit 0
  eval "$gw_stdout"
  assert_equals '' "${GW_SESSION:-}${VITE_PROXY_TARGET:-}${GW_SESSION_LABEL:-}"
}

test_session_rejects_something_that_is_not_a_gateway() {
  given_alias alpha td@alpha.local
  run_gw session alph
  assert_exit 2
  assert_equals '' "$gw_stdout"
  assert_contains "$gw_stderr" 'Not a saved alias or an ssh address: alph'
  assert_contains "$gw_stderr" 'Did you mean: alpha'
}

test_session_show_and_off_without_a_session_print_no_shell_code() {
  run_gw session
  assert_exit 0
  assert_equals '' "$gw_stdout"
  assert_contains "$gw_stderr" 'No session is active.'
  run_gw session off
  assert_exit 0
  assert_equals '' "$gw_stdout"
}

test_session_help_never_reaches_stdout() {
  run_gw session --help
  assert_exit 0
  assert_equals '' "$gw_stdout"
  assert_contains "$gw_stderr" 'gw session <gateway> [target...]'
}

test_session_gateway_is_used_by_other_commands_and_explicit_one_wins() {
  given_alias bravo td@bravo.local
  given_remote_service transceiver 96bd87881111
  GW_SESSION=td@alpha.local run_gw status
  assert_contains "$gw_stderr" 'Gateway: td@alpha.local (session)'
  GW_SESSION=td@alpha.local run_gw status bravo
  assert_contains "$gw_stderr" 'Gateway: td@bravo.local'
  assert_lacks "$gw_stderr" '(session)'
}
