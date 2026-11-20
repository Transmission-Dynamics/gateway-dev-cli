test_health_shows_resources_as_bars() {
  given_alias alpha td@alpha.local
  given_gateway_health 78000 750000
  run_gw health alpha
  assert_exit 0
  assert_contains "$gw_stdout" 'Resources  up 21h 40m'
  assert_contains "$gw_stdout" '  CPU      ██░░░░░░░░   22%  load 0.88 on 4 CPUs'
  assert_contains "$gw_stdout" '  Memory   ██████░░░░   62%  732 MB free of 1.9 GB'
  assert_contains "$gw_stdout" '  SD card  █░░░░░░░░░    3%  27.8 GB free'
  assert_contains "$gw_stdout" '  System   ███░░░░░░░   32%  3.2 GB free'
}

test_health_colours_high_memory_and_full_disks() {
  given_alias alpha td@alpha.local
  given_gateway_health 78000 200000
  GW_TEST_SD_USED_KB=28000000 GW_COLOR=always run_gw health alpha
  assert_contains "$gw_stdout" $'\e[1m\e[31m█████████\e[0m'
  assert_contains "$gw_stdout" $'\e[1m\e[31m 90%\e[0m'
  assert_contains "$gw_stdout" $'\e[1m\e[31m 93%\e[0m'
}

test_health_rejects_extra_arguments() {
  given_alias alpha td@alpha.local
  run_gw health alpha rest-api
  assert_exit 2
  assert_contains "$gw_stderr" 'gw health takes only a gateway, not: rest-api'
}

test_health_watch_refreshes_until_stopped() {
  given_alias alpha td@alpha.local
  given_gateway_health
  GW_HEALTH_WATCH_SECONDS=1 "$GW_BIN" health alpha --watch > "$GW_TEST_DIR/stdout" 2> "$GW_TEST_DIR/stderr" < /dev/null &
  local gw_pid=$! waited=0
  while (( $(grep -c '^Resources ' "$GW_TEST_DIR/stdout" 2> /dev/null || true) < 2 && waited < 150 )); do
    sleep 0.1
    waited=$(( waited + 1 ))
  done
  kill -TERM $gw_pid
  gw_exit=0
  wait $gw_pid || gw_exit=$?
  gw_stdout=$(< "$GW_TEST_DIR/stdout")
  gw_stderr=$(< "$GW_TEST_DIR/stderr")
  gw_output=$gw_stdout$'\n'$gw_stderr
  assert_exit 0
  (( $(grep -c '^Resources ' "$GW_TEST_DIR/stdout") >= 2 )) || fail 'expected at least two refreshes'
  (( $(grep -c '^  SD card ' "$GW_TEST_DIR/stdout") == $(grep -c '^Resources ' "$GW_TEST_DIR/stdout") )) ||
    fail 'each refresh should show each disk once'
  assert_contains "$gw_stderr" 'Refreshing every 1s, Ctrl+C to stop'
}
