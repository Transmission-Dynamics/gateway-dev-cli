test_cli_help_lists_every_command_and_exits_zero() {
  run_gw --help
  assert_exit 0
  local command
  for command in session status health devices submodules logs deploy restart ssh alias link target use doctor; do
    assert_contains "$gw_stdout" "  $command "
  done
  assert_equals '' "$gw_stderr"
}

test_cli_without_arguments_shows_help() {
  run_gw
  assert_exit 0
  assert_contains "$gw_stdout" 'gw <command> [gateway] [arguments]'
}

test_cli_command_help_shows_usage_options_and_examples() {
  run_gw status --help
  assert_exit 0
  assert_contains "$gw_stdout" 'gw status [gateway] [service...]'
  assert_contains "$gw_stdout" '-a, --all'
  assert_contains "$gw_stdout" '$ gw status alpha'
}

test_cli_help_command_matches_help_flag() {
  run_gw help deploy
  local from_help_command=$gw_stdout
  run_gw deploy -h
  assert_equals "$from_help_command" "$gw_stdout"
}

test_cli_unknown_command_suggests_the_closest() {
  run_gw stauts
  assert_exit 2
  assert_contains "$gw_stderr" 'Unknown command: stauts'
  assert_contains "$gw_stderr" 'Did you mean: gw status'
  assert_equals '' "$gw_stdout"
}

test_cli_unknown_option_suggests_and_shows_usage() {
  run_gw status --al
  assert_exit 2
  assert_contains "$gw_stderr" 'Unknown option for gw status: --al (did you mean --all?)'
  assert_contains "$gw_stderr" 'gw status [gateway] [service...]'
}

test_cli_command_alias_runs_the_command() {
  run_gw targets
  assert_exit 0
  assert_contains "$gw_stderr" 'No targets yet'
}

test_cli_output_has_no_colour_codes_when_piped() {
  unset GW_COLOR
  run_gw --help
  assert_lacks "$gw_stdout" $'\e['
}

test_cli_colour_can_be_forced_and_no_color_wins() {
  GW_COLOR=always run_gw --help
  assert_contains "$gw_stdout" $'\e['
  NO_COLOR=1 GW_COLOR=always run_gw --help
  assert_lacks "$gw_stdout" $'\e['
}

test_cli_version_prints_one_line() {
  run_gw --version
  assert_exit 0
  assert_contains "$gw_stdout" 'gw '
}

test_cli_missing_gateway_explains_both_ways_out() {
  given_alias alpha td@alpha.local
  run_gw status
  assert_exit 2
  assert_contains "$gw_stderr" 'No gateway given and no session is active.'
  assert_contains "$gw_stderr" 'gw status <gateway>'
  assert_contains "$gw_stderr" 'gw session <gateway>'
  assert_contains "$gw_stderr" 'Saved gateways: alpha'
}

test_cli_misspelled_alias_is_rejected_even_inside_a_session() {
  given_alias bravo td@bravo.local
  GW_SESSION=td@alpha.local run_gw restart bravoo rest-api
  assert_exit 2
  assert_contains "$gw_stderr" 'Unknown gateway: bravoo'
  assert_contains "$gw_stderr" 'Did you mean: bravo'
  assert_equals '' "$(ssh_log)"
}

test_cli_messages_use_emojis_only_on_a_colour_terminal() {
  given_alias alpha td@alpha.local
  GW_COLOR=always run_gw alias rm alpha
  assert_contains "$gw_stderr" '✅'
  given_alias alpha td@alpha.local
  GW_COLOR=always GW_EMOJI=never run_gw alias rm alpha
  assert_contains "$gw_stderr" '✓'
  assert_lacks "$gw_stderr" '✅'
  given_alias alpha td@alpha.local
  run_gw alias rm alpha
  assert_lacks "$gw_stderr" '✅'
}

test_cli_combined_short_flags_are_split() {
  given_alias alpha td@alpha.local
  given_repo rest-api
  run_gw deploy alpha rest-api -nv
  assert_exit 0
  assert_contains "$gw_stderr" 'Dry run'
  run_gw deploy alpha rest-api -nx
  assert_exit 2
  assert_contains "$gw_stderr" 'Unknown option for gw deploy: -x'
}
