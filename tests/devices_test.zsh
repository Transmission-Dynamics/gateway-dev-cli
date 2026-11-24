given_devices_gateway() {
  given_alias alpha td@alpha.local
  given_last_device a1a1a1a1a1a1 SBR -44 4 2.99 23.4
  given_last_device b2b2b2b2b2b2 SOP -60 300 3.51 22.8
  given_last_device c3c3c3c3c3c3 MT-V2 -88 30 2.99 0
  given_last_device d4d4d4d4d4d4 GNSS_BT -29 900 0 0
  given_last_device e5e5e5e5e5e5 SBR -47 10800
}

test_devices_lists_connectable_devices_newest_first() {
  given_devices_gateway
  run_gw devices alpha
  assert_exit 0
  assert_line_order "$gw_stdout" a1a1a1a1a1a1 c3c3c3c3c3c3
  assert_line_order "$gw_stdout" c3c3c3c3c3c3 b2b2b2b2b2b2
  assert_line_order "$gw_stdout" b2b2b2b2b2b2 d4d4d4d4d4d4
  [[ $gw_stdout =~ 'a1a1a1a1a1a1  SBR      -44   [45]s +-' ]] ||
    fail "unexpected row for a1a1a1a1a1a1 in: $gw_stdout"
  assert_contains "$gw_stdout" '4 devices seen in the last 2h'
  assert_lacks "$gw_stdout" 'LAST SEEN'
  assert_lacks "$gw_stdout" 'TEMP'
  assert_lacks "$gw_stdout" 'BATTERY'
}

test_devices_leaves_out_devices_older_than_the_window() {
  given_devices_gateway
  run_gw devices alpha
  assert_lacks "$gw_stdout" e5e5e5e5e5e5
  run_gw devices alpha --since 1m
  assert_contains "$gw_stdout" '2 devices seen in the last 1m'
  assert_lacks "$gw_stdout" b2b2b2b2b2b2
  run_gw devices alpha --since=1d
  assert_contains "$gw_stdout" e5e5e5e5e5e5
}

test_devices_shows_only_the_newest_record_of_each_device() {
  given_alias alpha td@alpha.local
  given_last_device a1a1a1a1a1a1 SBR -80 120
  given_last_device a1a1a1a1a1a1 SBR -44 3
  run_gw devices alpha
  assert_contains "$gw_stdout" '1 device seen in the last 2h'
  assert_contains "$gw_stdout" 'SBR   -44'
}

test_devices_formats_ages_and_missing_measurements() {
  given_devices_gateway
  run_gw devices alpha
  [[ $gw_stdout =~ 'b2b2b2b2b2b2  SOP .* 5m [0-5][0-9]s ' ]] || fail "expected about 5m 00s: $gw_stdout"
  [[ $gw_stdout =~ '15m [0-5][0-9]s  -' ]] || fail "expected about 15m 00s: $gw_stdout"
  run_gw devices alpha --verbose
  [[ $gw_stdout =~ '15m [0-5][0-9]s  -        -' ]] || fail "missing measurements should show as -: $gw_stdout"
  [[ $gw_stdout =~ 'a1a1a1a1a1a1  SBR .*2\.99 V   23\.4 °C' ]] || fail "--verbose should show the battery and temperature: $gw_stdout"
  [[ $gw_stdout =~ 'c3c3c3c3c3c3  MT-V2 .*2\.99 V   -  ' ]] || fail "temperature 0 should show as -: $gw_stdout"
  run_gw devices alpha -s 1d
  assert_contains "$gw_stdout" '3h 00m'
}

test_devices_filters_by_type_and_uuid() {
  given_devices_gateway
  run_gw devices alpha --type sbr
  assert_contains "$gw_stdout" a1a1a1a1a1a1
  assert_lacks "$gw_stdout" b2b2b2b2b2b2
  assert_contains "$gw_stdout" '1 device seen in the last 2h (type sbr)'

  run_gw devices alpha b2b2b2b2b2b2 c3c3c3c3c3c3
  assert_contains "$gw_stdout" '2 devices seen in the last 2h (b2b2b2b2b2b2, c3c3c3c3c3c3)'
  assert_lacks "$gw_stdout" a1a1a1a1a1a1
}

test_devices_colours_signal_strength_and_age() {
  given_devices_gateway
  GW_COLOR=always run_gw devices alpha
  assert_contains "$gw_stdout" $'\e[1m\e[31m-88\e[0m'
  assert_contains "$gw_stdout" $'  -44  '
  [[ $gw_stdout == *$'\e[32m'<->s$'\e[0m'* ]] || fail 'a fresh device should be green'
  [[ $gw_stdout == *$'\e[33m5m '<->$'s\e[0m'* ]] || fail 'a device seen 5 minutes ago should be yellow'
  [[ $gw_stdout == *$'\e[90m15m '<->$'s\e[0m'* ]] || fail 'a device seen 15 minutes ago should be grey'
}

test_devices_with_nothing_recent_says_so() {
  given_alias alpha td@alpha.local
  given_last_device e5e5e5e5e5e5 SBR -47 10800
  run_gw devices alpha --type SOP
  assert_exit 0
  assert_equals '' "$gw_stdout"
  assert_contains "$gw_stderr" 'No connectable device seen on td@alpha.local in the last 2h (type SOP)'
}

test_devices_without_a_last_device_table_explains_why() {
  given_alias alpha td@alpha.local
  run_gw devices alpha
  assert_exit 1
  assert_contains "$gw_stderr" 'last-device.db on this gateway, the transceiver has not recorded any device yet'
}

test_devices_rejects_bad_option_values_before_connecting() {
  given_alias alpha td@alpha.local
  run_gw devices alpha --since 1x
  assert_exit 2
  assert_contains "$gw_stderr" 'Not a time like 30s, 10m, 2h or 1d: 1x'
  run_gw devices alpha --since
  assert_exit 2
  assert_contains "$gw_stderr" '--since needs a value: --since <time>'
  run_gw devices alpha --watch=yes
  assert_exit 2
  assert_contains "$gw_stderr" '--watch takes no value'
  assert_equals '' "$(ssh_log)"
}

test_devices_unreachable_gateway_gives_a_clear_error() {
  run_gw devices td@unreachable.local
  assert_exit 1
  assert_contains "$gw_stderr" 'Cannot reach td@unreachable.local over ssh.'
}

test_devices_watch_refreshes_until_stopped() {
  given_devices_gateway
  run_gw_watch 'devices seen' devices alpha
}

test_devices_completion_and_help() {
  given_alias alpha td@alpha.local
  run_gw __complete devices
  assert_contains "$gw_stdout" $'alpha\t'
  assert_contains "$gw_stdout" $'--since\t'
  run_gw __complete devices alpha --since 10m
  assert_lacks "$gw_stdout" $'alpha\t'
  run_gw devices --help
  assert_contains "$gw_stdout" '-s, --since <time>'
}

test_devices_show_the_tasks_waiting_for_each_device() {
  given_devices_gateway
  given_pending_task a1a1a1a1a1a1 upload
  given_pending_task a1a1a1a1a1a1 config
  given_pending_task c3c3c3c3c3c3 dfu
  given_pending_task ffffffffffff upload
  run_gw devices alpha
  [[ $gw_stdout =~ 'a1a1a1a1a1a1 .* config, upload' ]] || fail "expected both tasks of a1a1a1a1a1a1: $gw_stdout"
  [[ $gw_stdout =~ 'c3c3c3c3c3c3 .* dfu' ]] || fail "expected the dfu task: $gw_stdout"
  [[ $gw_stdout =~ 'b2b2b2b2b2b2 .* -' ]] || fail "a device without tasks shows -: $gw_stdout"
  assert_lacks "$gw_stdout" ffffffffffff
  assert_lacks "$gw_stderr" 'Could not read'
}

test_devices_still_list_when_tasks_cannot_be_read() {
  given_devices_gateway
  touch "$GW_TEST_DIR/mongo-fails"
  run_gw devices alpha
  assert_exit 0
  [[ $gw_stdout =~ 'a1a1a1a1a1a1 .*  \?' ]] || fail "expected ? for unknown tasks: $gw_stdout"
  assert_contains "$gw_stderr" 'Could not read the pending tasks on td@alpha.local, TASKS shows ?'
}
