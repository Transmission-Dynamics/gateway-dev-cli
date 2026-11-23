given_deploy_setup() {
  given_alias alpha td@alpha.local
  given_repo transceiver
  given_repo rest-api
  given_repo frontend
}

test_deploy_without_services_deploys_nothing() {
  given_deploy_setup
  run_gw deploy alpha
  assert_exit 2
  assert_contains "$gw_stderr" 'No services given, nothing deployed.'
  GW_SESSION=td@alpha.local run_gw deploy
  assert_exit 2
  assert_equals '' "$(npm_log)"
}

test_deploy_runs_only_the_listed_services_in_link_order() {
  given_deploy_setup
  run_gw deploy alpha frontend transceiver
  assert_exit 0
  assert_equals $'transceiver\trun deploy\ttd@alpha.local\nfrontend\trun deploy\ttd@alpha.local' \
    "$(npm_log | cut -f1-3)"
}

test_deploy_points_the_target_at_the_gateway_only_during_the_run() {
  given_deploy_setup
  run_gw deploy alpha rest-api
  assert_exit 0
  assert_contains "$(npm_log)" $'rest-api\trun deploy\ttd@alpha.local'
  assert_file_equals "$HOME/repos/rest-api/scripts/target" 'td@original.local'
  assert_missing "$HOME/repos/rest-api/scripts/target.gw-backup"
}

test_deploy_restores_a_target_registered_under_multiple_names() {
  given_deploy_setup
  run_gw target add rest "$HOME/repos/rest-api/scripts/target"
  assert_exit 0
  run_gw deploy alpha rest-api
  assert_exit 0
  assert_file_equals "$HOME/repos/rest-api/scripts/target" 'td@original.local'
  assert_missing "$HOME/repos/rest-api/scripts/target.gw-backup"
}

test_deploy_reports_each_step_and_ends_with_the_status_table() {
  given_deploy_setup
  given_remote_unit rest-api
  run_gw deploy alpha rest-api
  local commit=$(repo_commit rest-api)
  assert_contains "$gw_stderr" "==> Deploying rest-api main @ ${commit[1,8]} from ~/repos/rest-api to td@alpha.local"
  assert_contains "$gw_stderr" '✓ Building and deploying (npm run deploy)'
  assert_contains "$gw_stderr" "✓ Deployed rest-api @ ${commit[1,8]}"
  assert_contains "$gw_stdout" "rest-api  ${commit[1,8]}"
  assert_contains "$gw_stdout" 'Test User    running'
}

test_deploy_record_goes_stale_after_a_deploy_without_gw() {
  given_deploy_setup
  run_gw deploy alpha rest-api
  assert_contains "$gw_stdout" 'Test User'
  print -r -- 'ffffffffffffffff' > "$GW_TEST_DIR/jrd/rest-api/version"
  run_gw status alpha rest-api
  assert_contains "$gw_stdout" 'rest-api  ffffffff'
  assert_lacks "$gw_stdout" 'Test User'
}

test_deploy_failure_restores_the_target_and_summarises() {
  given_deploy_setup
  touch "$GW_TEST_DIR/npm-fails-rest-api"
  run_gw deploy alpha transceiver rest-api frontend
  assert_exit 1
  assert_file_equals "$HOME/repos/rest-api/scripts/target" 'td@original.local'
  assert_missing "$HOME/repos/rest-api/scripts/target.gw-backup"
  assert_contains "$gw_stderr" '✗ Building and deploying (npm run deploy) failed'
  assert_contains "$gw_stderr" '│ npm ERR! build of rest-api failed'
  assert_contains "$gw_stderr" 'Full output:'
  assert_contains "$gw_stderr" 'Deploy of rest-api failed, stopping.'
  assert_contains "$gw_stderr" 'Not started: frontend'
  assert_contains "$gw_stderr" 'Already deployed in this run: transceiver'
  assert_contains "$gw_stdout" 'transceiver'
  assert_lacks "$(npm_log)" frontend
}

test_deploy_verbose_streams_the_build_output() {
  given_deploy_setup
  run_gw deploy alpha rest-api --verbose
  assert_exit 0
  assert_contains "$gw_stderr" '> fake npm run deploy for rest-api'
}

test_deploy_warns_about_uncommitted_changes() {
  given_deploy_setup
  print -r -- 'wip' > "$HOME/repos/rest-api/wip.txt"
  run_gw deploy alpha rest-api
  assert_exit 0
  assert_contains "$gw_stderr" '1 uncommitted changes are deployed too'
}

test_deploy_restores_a_backup_left_by_a_killed_run() {
  given_deploy_setup
  print -r -- 'td@really-original.local' > "$HOME/repos/rest-api/scripts/target.gw-backup"
  run_gw deploy alpha rest-api
  assert_exit 0
  assert_contains "$gw_stderr" 'left over from an interrupted deploy'
  assert_file_equals "$HOME/repos/rest-api/scripts/target" 'td@really-original.local'
}

test_deploy_stops_before_building_when_the_gateway_is_unreachable() {
  given_deploy_setup
  run_gw deploy td@unreachable.local rest-api
  assert_exit 1
  assert_contains "$gw_stderr" 'Cannot reach td@unreachable.local over ssh.'
  assert_equals '' "$(npm_log)"
}

test_deploy_unknown_service_suggests_and_lists_linked_ones() {
  given_deploy_setup
  run_gw deploy alpha rest
  assert_exit 1
  assert_contains "$gw_stderr" 'Unknown service: rest'
  assert_contains "$gw_stderr" 'Did you mean: rest-api'
  assert_contains "$gw_stderr" 'Linked services: transceiver, rest-api, frontend'
  assert_equals '' "$(npm_log)"
}

test_deploy_misspelled_service_with_commit_is_not_taken_for_an_address() {
  given_deploy_setup
  GW_SESSION=td@alpha.local run_gw deploy rest@abc123 frontend
  assert_exit 2
  assert_contains "$gw_stderr" 'rest@abc123 looks like service@commit, but no service named rest is linked.'
  assert_contains "$gw_stderr" 'Did you mean: rest-api@abc123'
  assert_equals '' "$(npm_log)$(ssh_log)"
}

test_deploy_without_a_target_file_explains_how_to_add_one() {
  given_deploy_setup
  : > "$(config_file targets)"
  run_gw deploy alpha rest-api
  assert_exit 1
  assert_contains "$gw_stderr" 'No target file is configured inside ~/repos/rest-api'
  assert_contains "$gw_stderr" 'gw target add rest-api'
}

test_deploy_uses_the_session_gateway() {
  given_deploy_setup
  GW_SESSION=td@bravo.local run_gw deploy rest-api
  assert_exit 0
  assert_contains "$(npm_log)" $'rest-api\trun deploy\ttd@bravo.local'
}

test_deploy_pinned_commit_builds_in_a_temporary_checkout() {
  given_deploy_setup
  local pinned=$(repo_commit rest-api)
  given_second_commit rest-api
  print -r -- 'SECRET=1' > "$HOME/repos/rest-api/.env"

  run_gw deploy alpha "rest-api@${pinned[1,8]}"
  assert_exit 0
  assert_contains "$gw_stderr" '✓ [1/5] Checking out'
  assert_contains "$gw_stderr" 'Copied .env from your working copy'
  assert_contains "$gw_stderr" '✓ [3/5] Installing dependencies (npm ci)'
  assert_contains "$gw_stderr" '✓ [5/5] Removing the temporary checkout'
  assert_file_equals "$GW_TEST_DIR/jrd/rest-api/version" "$pinned"
  assert_contains "$(npm_log)" $'rest-api\tci\ttd@alpha.local'
  assert_lacks "$(npm_log | cut -f4)" "$HOME/repos/rest-api"
  assert_file_equals "$HOME/repos/rest-api/scripts/target" 'td@original.local'
  assert_equals "$(repo_commit rest-api)" "$(git -C "$HOME/repos/rest-api" rev-parse main)"
  assert_equals '1' "$(git -C "$HOME/repos/rest-api" worktree list | wc -l | tr -d ' ')"
  assert_equals '' "$(print -l "$TMPDIR"/gw-deploy-*(N))"
}

test_deploy_pinned_commit_in_a_session_is_not_taken_for_a_gateway() {
  given_deploy_setup
  local pinned=$(repo_commit frontend)
  GW_SESSION=td@alpha.local run_gw deploy "frontend@$pinned"
  assert_exit 0
  assert_contains "$gw_stderr" 'Gateway: td@alpha.local (session)'
}

test_deploy_pinned_failure_removes_the_temporary_checkout() {
  given_deploy_setup
  touch "$GW_TEST_DIR/npm-fails-rest-api"
  run_gw deploy alpha rest-api@HEAD
  assert_exit 1
  assert_contains "$gw_stderr" '[3/5] Installing dependencies (npm ci) failed'
  assert_equals '1' "$(git -C "$HOME/repos/rest-api" worktree list | wc -l | tr -d ' ')"
  assert_equals '' "$(print -l "$TMPDIR"/gw-deploy-*(N))"
}

test_deploy_unknown_commit_suggests_a_fetch() {
  given_deploy_setup
  run_gw deploy alpha rest-api@deadbeef
  assert_exit 1
  assert_contains "$gw_stderr" 'deadbeef is not a commit or tag in ~/repos/rest-api.'
  assert_contains "$gw_stderr" 'git -C ~/repos/rest-api fetch --tags'
}

test_deploy_dry_run_shows_the_plan_and_changes_nothing() {
  given_deploy_setup
  local head=$(repo_commit rest-api)
  given_remote_service rest-api "$head"
  given_remote_service frontend 1111111122222222
  print -r -- 'wip' > "$HOME/repos/frontend/wip.txt"
  git -C "$HOME/repos/transceiver" tag v1.0.0

  run_gw deploy alpha --dry-run rest-api frontend transceiver@v1.0.0
  assert_exit 0
  assert_contains "$gw_stderr" 'Dry run, nothing is changed'
  assert_contains "$gw_stdout" "transceiver  v1.0.0  ${$(repo_commit transceiver)[1,8]}  -             temporary checkout"
  assert_contains "$gw_stdout" "rest-api     main    ${head[1,8]}  ${head[1,8]}      clean"
  assert_contains "$gw_stdout" "11111111      1 uncommitted"
  assert_equals '' "$(npm_log)"
  assert_file_equals "$GW_TEST_DIR/jrd/rest-api/version" "$head"
  assert_missing "$GW_TEST_DIR/jrd/rest-api/.gw-deployed-by"
}

test_deploy_dry_run_against_an_unreachable_gateway_still_prints_the_plan() {
  given_deploy_setup
  run_gw deploy td@unreachable.local -n rest-api
  assert_exit 1
  assert_contains "$gw_stdout" 'rest-api  main'
  assert_contains "$gw_stdout" '?'
}

test_deploy_unknown_option_is_rejected() {
  given_deploy_setup
  run_gw deploy alpha frontend --74695ef8
  assert_exit 2
  assert_contains "$gw_stderr" 'Unknown option for gw deploy: --74695ef8'
  assert_equals '' "$(npm_log)"
}

test_deploy_interrupted_restores_the_target_and_exits_130() {
  given_deploy_setup
  touch "$GW_TEST_DIR/npm-pause"
  "$GW_BIN" deploy alpha rest-api frontend > "$GW_TEST_DIR/stdout" 2> "$GW_TEST_DIR/stderr" < /dev/null &
  local gw_pid=$! waited=0
  while [[ ! -f $GW_TEST_DIR/npm-paused ]] && (( waited < 100 )); do
    sleep 0.1
    waited=$(( waited + 1 ))
  done
  [[ -f $GW_TEST_DIR/npm-paused ]] || fail 'npm never started'
  assert_file_equals "$HOME/repos/rest-api/scripts/target" 'td@alpha.local'

  kill -TERM $gw_pid
  rm "$GW_TEST_DIR/npm-pause"
  gw_exit=0
  wait $gw_pid || gw_exit=$?
  gw_stderr=$(< "$GW_TEST_DIR/stderr")
  assert_exit 130
  assert_contains "$gw_stderr" 'Interrupted'
  assert_file_equals "$HOME/repos/rest-api/scripts/target" 'td@original.local'
  assert_missing "$HOME/repos/rest-api/scripts/target.gw-backup"
  assert_lacks "$(npm_log)" frontend
}
