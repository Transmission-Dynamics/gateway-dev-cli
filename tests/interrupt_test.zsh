run_gw_interrupted() {
  touch "$GW_TEST_DIR/npm-pause"
  gw_exit=0
  python3 "$TESTS_DIR/interrupt.py" "$GW_BIN" "$@" || gw_exit=$?
  gw_stdout=$(< "$GW_TEST_DIR/stdout")
  gw_stderr=$(< "$GW_TEST_DIR/stderr")
  gw_output=$gw_stdout$'\n'$gw_stderr
}

assert_interrupted_deploy_cleaned_up() {
  assert_exit 130
  assert_contains "$gw_stderr" 'Interrupted'
  assert_file_equals "$HOME/repos/rest-api/scripts/target" 'td@original.local'
  assert_missing "$HOME/repos/rest-api/scripts/target.gw-backup"
  assert_missing "$GW_TEST_DIR/jrd/rest-api/version"
  assert_lacks "$(npm_log)" frontend
  assert_equals '' "$(print -l "$TMPDIR"/gw.*(N) "$TMPDIR"/gw-deploy-*(N))"
  assert_equals '1' "$(git -C "$HOME/repos/rest-api" worktree list | wc -l | tr -d ' ')"
}

test_interrupt_deploy_restores_the_target_and_stops_children() {
  given_deploy_setup
  run_gw_interrupted deploy alpha rest-api frontend
  assert_interrupted_deploy_cleaned_up
}

test_interrupt_verbose_deploy_restores_the_target_and_stops_children() {
  given_deploy_setup
  run_gw_interrupted deploy alpha rest-api frontend --verbose
  assert_interrupted_deploy_cleaned_up
}

test_interrupt_pinned_deploy_removes_the_temporary_checkout() {
  given_deploy_setup
  run_gw_interrupted deploy alpha rest-api@HEAD frontend
  assert_interrupted_deploy_cleaned_up
}
