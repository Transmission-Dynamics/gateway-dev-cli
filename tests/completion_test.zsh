test_completion_offers_commands_with_summaries() {
  run_gw __complete
  assert_exit 0
  assert_contains "$gw_stdout" $'status\tShow what is deployed on a gateway and whether it runs'
  assert_contains "$gw_stdout" $'deploy\t'
}

test_completion_offers_gateways_then_services_and_flags() {
  given_alias alpha td@alpha.local
  given_repo rest-api
  run_gw __complete status
  assert_contains "$gw_stdout" $'alpha\ttd@alpha.local'
  assert_contains "$gw_stdout" $'rest-api\t~/repos/rest-api'
  assert_contains "$gw_stdout" $'--all\t'

  run_gw __complete deploy alpha
  assert_lacks "$gw_stdout" $'alpha\t'
  assert_contains "$gw_stdout" $'rest-api\t'
  assert_contains "$gw_stdout" $'--dry-run\t'
}

test_completion_knows_the_setup_subcommands() {
  given_alias alpha td@alpha.local
  given_repo rest-api
  run_gw __complete alias rm
  assert_contains "$gw_stdout" $'alpha\t'
  run_gw __complete link rest-api
  assert_equals ':directories' "$gw_stdout"
  run_gw __complete target add rest-api
  assert_equals ':files' "$gw_stdout"
  run_gw __complete session
  assert_contains "$gw_stdout" $'off\t'
  assert_contains "$gw_stdout" $'alpha\t'
}

test_completion_of_an_unknown_command_offers_nothing() {
  run_gw __complete nosuch
  assert_exit 0
  assert_equals '' "$gw_stdout"
}
