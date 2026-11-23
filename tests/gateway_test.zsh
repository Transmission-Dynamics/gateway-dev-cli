test_status_lists_deployed_services_newest_first() {
  given_alias alpha td@alpha.local
  given_remote_service rest-api 7bcc430599999999 202610291259
  given_remote_service transceiver 96bd878811111111 202610301118
  given_remote_service redis b765d0db22222222 202608200748
  given_remote_unit rest-api
  given_remote_unit transceiver ActiveState=activating SubState=auto-restart

  run_gw status alpha
  assert_exit 0
  assert_equals 'SERVICE      COMMIT    DEPLOYED (UTC)    STATE       STARTED
transceiver  96bd8788  2026-10-30 11:18  crash loop  -
rest-api     7bcc4305  2026-10-29 12:59  running     20h 05m ago' "$gw_stdout"
  assert_contains "$gw_stderr" '1 turned off or not a service, hidden. Show them with: gw status alpha --all'
}

test_status_all_and_named_services_show_hidden_ones() {
  given_alias alpha td@alpha.local
  given_remote_service redis b765d0db22222222 202608200748
  given_remote_service gpio 08dae81a 202603180706
  given_remote_unit gpio ActiveState=inactive SubState=dead UnitFileState=disabled
  run_gw status alpha
  assert_equals '' "$gw_stdout"
  assert_contains "$gw_stderr" '2 turned off or not a service, hidden'
  given_remote_service lora-server 3c3c3c3c 202610010900
  given_remote_unit lora-server ActiveState=activating SubState=auto-restart Result=exec-condition
  run_gw status alpha
  assert_contains "$gw_stderr" '3 turned off or not a service, hidden'
  assert_lacks "$gw_stdout" 'crash loop'
  run_gw status alpha --all
  assert_contains "$gw_stdout" 'lora-server  3c3c3c3c  2026-10-01 09:00  off by config  -'
  assert_contains "$gw_stdout" 'redis        b765d0db  2026-08-20 07:48  not a service  -'
  assert_contains "$gw_stdout" 'gpio         08dae81a  2026-03-18 07:06  disabled       -'
  assert_lacks "$gw_stderr" hidden
  run_gw status alpha redis
  assert_contains "$gw_stdout" 'redis    b765d0db'
}

test_status_formats_how_long_ago_a_service_started() {
  given_alias alpha td@alpha.local
  local service started
  for service started in seconds 'Mon 2026-11-03 06:18:00 UTC' minutes 'Mon 2026-11-03 06:06:15 UTC' \
    hours "$FIXED_NOW" days 'Fri 2026-10-30 03:13:15 UTC'; do
    given_remote_service $service aaaaaaaa
    given_remote_unit $service "ActiveEnterTimestamp=$started"
  done
  run_gw status alpha
  assert_contains "$gw_stdout" 'seconds  aaaaaaaa'
  [[ $gw_stdout =~ 'seconds .* 15s ago' ]] || fail "expected 15s ago: $gw_stdout"
  [[ $gw_stdout =~ 'minutes .* 12m ago' ]] || fail "expected 12m ago: $gw_stdout"
  [[ $gw_stdout =~ 'hours .* 20h 05m ago' ]] || fail "expected 20h 05m ago: $gw_stdout"
  [[ $gw_stdout =~ 'days .* 4d 3h ago' ]] || fail "expected 4d 3h ago: $gw_stdout"
}

test_status_maps_every_systemd_state() {
  given_alias alpha td@alpha.local
  local service
  for service in up finished oneshot off masked starting stopping stopped crashed looping skipped; do
    given_remote_service $service aaaaaaaa
  done
  given_remote_unit up
  given_remote_unit finished SubState=exited
  given_remote_unit oneshot ActiveState=inactive SubState=dead Type=oneshot
  given_remote_unit off ActiveState=inactive SubState=dead UnitFileState=disabled
  given_remote_unit masked LoadState=masked ActiveState=inactive
  given_remote_unit starting ActiveState=activating SubState=start
  given_remote_unit stopping ActiveState=deactivating SubState=stop
  given_remote_unit stopped ActiveState=inactive SubState=dead
  given_remote_unit crashed ActiveState=failed SubState=failed
  given_remote_unit looping ActiveState=activating SubState=auto-restart Result=exit-code
  given_remote_unit skipped ActiveState=activating SubState=auto-restart Result=exec-condition

  run_gw status alpha --all
  local expectation
  for expectation in 'up running' 'finished done' 'oneshot idle' 'off disabled' 'masked disabled' \
    'starting starting' 'stopping stopping' 'stopped stopped' 'crashed crashed' \
    'looping crash loop' 'skipped off by config'; do
    [[ $gw_stdout =~ "${expectation%% *} +aaaaaaaa +[0-9: -]+ +${expectation#* }" ]] ||
      fail "expected service ${expectation%% *} to be ${expectation#* }"
  done
}

test_status_named_services_include_ones_that_are_not_installed() {
  given_alias alpha td@alpha.local
  given_remote_service transceiver 96bd8788
  given_remote_unit transceiver
  run_gw status alpha transceiver nosuch
  assert_exit 0
  assert_contains "$gw_stdout" 'transceiver  96bd8788'
  assert_contains "$gw_stdout" 'nosuch       -         -                 not installed'
}

test_status_all_adds_units_without_a_deployed_commit() {
  given_alias alpha td@alpha.local
  given_remote_service transceiver 96bd8788
  given_remote_unit transceiver
  given_remote_unit mongodb
  run_gw status alpha
  assert_lacks "$gw_stdout" mongodb
  run_gw status alpha --all
  assert_contains "$gw_stdout" 'mongodb      -         -                 running'
  run_gw status -a alpha
  assert_contains "$gw_stdout" mongodb
}

test_status_verbose_explains_every_state() {
  given_alias alpha td@alpha.local
  given_remote_service transceiver 96bd8788
  run_gw status alpha --verbose
  assert_contains "$gw_stdout" 'STATES'
  assert_contains "$gw_stdout" 'crash loop     keeps exiting and systemd keeps restarting it'
}

test_status_on_an_empty_gateway_says_so() {
  given_alias alpha td@alpha.local
  run_gw status alpha
  assert_exit 0
  assert_equals '' "$gw_stdout"
  assert_contains "$gw_stderr" 'Nothing is deployed on td@alpha.local'
}

test_status_unreachable_gateway_gives_a_clear_error() {
  run_gw status td@unreachable.local
  assert_exit 1
  assert_equals '' "$gw_stdout"
  assert_contains "$gw_stderr" 'Cannot reach td@unreachable.local over ssh.'
  assert_contains "$gw_stderr" 'Operation timed out'
  assert_contains "$gw_stderr" 'ssh td@unreachable.local'
}

test_status_on_a_host_that_is_not_a_gateway_reports_it() {
  rmdir "$GW_TEST_DIR/jrd"
  run_gw status td@laptop.local
  assert_exit 1
  assert_contains "$gw_stderr" 'does not look like a gateway'
}

test_status_passes_arguments_with_spaces_intact() {
  run_gw status td@alpha.local 'two words'
  assert_contains "$gw_stdout" 'two words  -'
}

test_submodules_prints_a_grid_sorted_by_use() {
  given_alias alpha td@alpha.local
  given_remote_manifest rest-api <<'JSON'
{ "name": "rest", "version": "v1.37.0-cc02c60", "submodules": [
  { "name": "td1023-db", "version": "v1.44.0-3a0ec49" },
  { "name": "protobuf", "version": "v1.1.0-4383403" } ] }
JSON
  given_remote_manifest transceiver <<'JSON'
{ "name": "transceiver", "version": "v1.47.1", "submodules": [
  { "name": "td1023-db", "version": "v1.45.2" } ] }
JSON
  given_remote_manifest iobroker <<'JSON'
{ "name": "iobroker", "version": "v1.7.1", "submodules": [] }
JSON

  run_gw submodules alpha
  assert_exit 0
  assert_contains "$gw_stdout" 'SERVICE      VERSION          td1023-db        protobuf
rest-api     v1.37.0-cc02c60  v1.44.0-3a0ec49  v1.1.0-4383403
transceiver  v1.47.1          v1.45.2          -
iobroker     v1.7.1           -                -'
  assert_contains "$gw_stdout" 'newest  behind  major version behind  unknown'
}

test_submodules_colours_versions_against_the_newest() {
  given_alias alpha td@alpha.local
  given_remote_manifest a <<'JSON'
{ "version": "v1.0.0", "submodules": [ { "name": "db", "version": "v2.1.0" } ] }
JSON
  given_remote_manifest b <<'JSON'
{ "version": "v1.0.0", "submodules": [ { "name": "db", "version": "v2.0.0-abc1234" } ] }
JSON
  given_remote_manifest c <<'JSON'
{ "version": "v1.0.0", "submodules": [ { "name": "db", "version": "v1.9.0" } ] }
JSON
  given_remote_manifest d <<'JSON'
{ "version": "v1.0.0", "submodules": [ { "name": "db", "version": "v0.0.0-def5678" } ] }
JSON
  GW_COLOR=always run_gw submodules alpha
  assert_contains "$gw_stdout" $'\e[32mv2.1.0\e[0m'
  assert_contains "$gw_stdout" $'\e[33mv2.0.0\e[0m\e[90m-abc1234\e[0m'
  assert_contains "$gw_stdout" $'\e[1m\e[31mv1.9.0\e[0m'
  assert_contains "$gw_stdout" $'\e[90mv0.0.0\e[0m'
}

test_submodules_named_service_without_manifest_is_shown() {
  given_alias alpha td@alpha.local
  given_remote_service gsm fbf8fe2e
  run_gw submodules alpha gsm
  assert_contains "$gw_stdout" 'gsm      (no manifest)'
}

test_submodules_without_any_manifest_says_so() {
  given_alias alpha td@alpha.local
  run_gw submodules alpha
  assert_exit 0
  assert_contains "$gw_stderr" 'No service on td@alpha.local has a manifest.json'
}

test_restart_restarts_each_unit_and_shows_status() {
  given_alias alpha td@alpha.local
  given_remote_service rest-api 7bcc4305
  given_remote_unit rest-api
  given_remote_service transceiver 96bd8788
  given_remote_unit transceiver
  run_gw restart alpha rest-api transceiver
  assert_exit 0
  assert_file_equals "$GW_TEST_DIR/restarts.log" $'td-rest-api.service\ntd-transceiver.service'
  assert_contains "$gw_stderr" 'Restarted rest-api, transceiver'
  assert_contains "$gw_stdout" 'rest-api     7bcc4305'
}

test_restart_reports_unknown_units_and_still_restarts_the_rest() {
  given_alias alpha td@alpha.local
  given_remote_service rest-api 7bcc4305
  given_remote_unit rest-api
  run_gw restart alpha nosuch rest-api
  assert_exit 1
  assert_contains "$gw_stderr" 'No unit td-nosuch.service on this gateway, skipped'
  assert_file_equals "$GW_TEST_DIR/restarts.log" 'td-rest-api.service'
  assert_contains "$gw_stdout" 'not installed'
}

test_restart_reports_a_unit_that_fails_to_restart() {
  given_alias alpha td@alpha.local
  given_remote_unit rest-api
  touch "$GW_TEST_DIR/units/td-rest-api.service.refuses-restart"
  run_gw restart alpha rest-api
  assert_exit 1
  assert_contains "$gw_stderr" 'Failed to restart td-rest-api.service'
}

test_restart_without_services_restarts_nothing() {
  given_alias alpha td@alpha.local
  run_gw restart alpha
  assert_exit 2
  assert_contains "$gw_stderr" 'No services given, nothing restarted.'
  assert_equals '' "$(ssh_log)"
}

test_ssh_opens_a_shell_or_runs_a_command() {
  given_alias alpha td@alpha.local
  run_gw ssh alpha
  assert_contains "$gw_stdout" 'interactive shell on td@alpha.local'
  run_gw ssh alpha echo --help
  assert_exit 0
  assert_equals '--help' "$gw_stdout"
}

test_ssh_passes_the_exit_code_of_the_remote_command() {
  run_gw ssh td@alpha.local exit 7
  assert_exit 7
}

test_ssh_unreachable_gateway_gives_a_clear_error() {
  run_gw ssh td@unreachable.local
  assert_exit 255
  assert_contains "$gw_stderr" 'Cannot reach td@unreachable.local over ssh.'
}

test_logs_follows_the_transceiver_by_default() {
  given_alias alpha td@alpha.local
  given_remote_unit transceiver
  run_gw logs alpha
  assert_exit 0
  assert_contains "$gw_stdout" 'log stream from td@alpha.local'
  assert_contains "$(ssh_log)" '/usr/jrd/scripts/show_logs.sh -u td-transceiver.service -n 50 -f'
}

test_logs_of_several_services_since_a_time_without_following() {
  given_alias alpha td@alpha.local
  given_remote_unit rest-api
  given_remote_unit voltage-monitor
  run_gw logs alpha rest-api voltage-monitor --since 10m --no-follow
  assert_exit 0
  assert_contains "$(ssh_log)" '/usr/jrd/scripts/show_logs.sh -u td-voltage-monitor.service -u td-rest-api.service --since=-600s'
  assert_lacks "$(ssh_log)" ' -f'
  run_gw logs alpha rest-api -n 200
  assert_contains "$(ssh_log)" '-u td-rest-api.service -n 200 -f'
}

test_logs_of_an_unknown_service_suggests_the_closest_one() {
  given_alias alpha td@alpha.local
  given_remote_unit voltage-monitor
  run_gw logs alpha voltage-monitr
  assert_exit 1
  assert_contains "$gw_stderr" 'No service voltage-monitr on td@alpha.local'
  assert_contains "$gw_stderr" 'Did you mean: gw logs alpha voltage-monitor'
  assert_lacks "$(ssh_log)" show_logs.sh
}

test_logs_rejects_bad_option_values_before_connecting() {
  given_alias alpha td@alpha.local
  run_gw logs alpha --since soon
  assert_exit 2
  assert_contains "$gw_stderr" 'Not a time like 30s, 10m, 2h or 1d: soon'
  run_gw logs alpha -n many
  assert_exit 2
  assert_contains "$gw_stderr" 'Not a number of lines: many'
  assert_equals '' "$(ssh_log)"
}

test_status_watch_refreshes_until_stopped() {
  given_alias alpha td@alpha.local
  given_remote_service rest-api 7bcc4305
  given_remote_unit rest-api
  GW_STATUS_WATCH_SECONDS=1 "$GW_BIN" status alpha --watch > "$GW_TEST_DIR/stdout" 2> "$GW_TEST_DIR/stderr" < /dev/null &
  local gw_pid=$! waited=0
  while (( $(grep -c '^SERVICE' "$GW_TEST_DIR/stdout" 2> /dev/null || true) < 2 && waited < 150 )); do
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
  (( $(grep -c '^SERVICE' "$GW_TEST_DIR/stdout") >= 2 )) || fail 'expected at least two refreshes'
  assert_contains "$gw_stderr" 'Refreshing every 1s, Ctrl+C to stop'
}

test_ssh_connections_are_shared_between_calls() {
  given_alias alpha td@alpha.local
  run_gw status alpha
  assert_contains "$(< "$GW_TEST_DIR/ssh-options.log")" 'ControlMaster=auto'
  assert_contains "$(< "$GW_TEST_DIR/ssh-options.log")" "ControlPath=$HOME/.cache/gw/ssh-%C"
  [[ -d $HOME/.cache/gw ]] || fail 'the ssh control folder was not created'
  [[ $(stat -f %Lp "$HOME/.cache/gw") == 700 ]] || fail 'the ssh control folder must be private'
}

test_logs_warns_when_a_service_wrote_nothing_the_journal_still_keeps() {
  given_alias alpha td@alpha.local
  given_remote_unit rest-api
  given_remote_unit transceiver
  mkdir -p "$GW_TEST_DIR/journal"
  print -r -- 'ts=1 msg=hello' > "$GW_TEST_DIR/journal/td-transceiver.service"
  print -r -- $(( GW_TEST_NOW - 5520 )) > "$GW_TEST_DIR/journal/oldest"
  run_gw logs alpha rest-api transceiver
  assert_exit 0
  assert_contains "$gw_stderr" 'rest-api wrote nothing in the last 1h 32m, all the journal keeps'
  assert_contains "$gw_stderr" 'Waiting for new lines; stop with Ctrl+C'
  assert_lacks "$gw_stderr" 'transceiver wrote nothing'
  assert_contains "$(ssh_log)" 'show_logs.sh'
  run_gw logs alpha transceiver
  assert_lacks "$gw_stderr" 'wrote nothing'
}
