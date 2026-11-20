test_alias_add_list_and_remove() {
  run_gw alias td@alpha.local alpha
  assert_exit 0
  run_gw alias td@bravo.local bravo
  assert_file_equals "$(config_file aliases)" $'alpha td@alpha.local\nbravo td@bravo.local'

  run_gw alias
  assert_equals $'NAME   ADDRESS\nalpha  td@alpha.local\nbravo  td@bravo.local' "$gw_stdout"

  run_gw alias rm bravo
  assert_exit 0
  assert_file_equals "$(config_file aliases)" 'alpha td@alpha.local'
}

test_alias_replaces_an_existing_name() {
  run_gw alias td@old.local alpha
  run_gw alias td@new.local alpha
  assert_file_equals "$(config_file aliases)" 'alpha td@new.local'
}

test_alias_rejects_names_that_would_be_ambiguous() {
  run_gw alias td@alpha.local man.ta
  assert_exit 1
  run_gw alias td@alpha.local off
  assert_exit 1
  given_repo rest-api
  run_gw alias td@alpha.local rest-api
  assert_exit 1
  assert_contains "$gw_stderr" 'already a linked service'
  assert_missing "$(config_file aliases)"
}

test_alias_remove_unknown_name_fails() {
  run_gw alias rm nosuch
  assert_exit 1
  assert_contains "$gw_stderr" 'No alias named: nosuch'
}

test_alias_wrong_argument_count_is_a_usage_error() {
  run_gw alias only-one
  assert_exit 2
  assert_contains "$gw_stderr" 'gw alias <address> <name>'
}

test_alias_list_when_empty_gives_a_hint() {
  run_gw alias
  assert_exit 0
  assert_contains "$gw_stderr" 'gw alias <address> <name>'
}

test_link_add_list_and_remove() {
  given_repo rest-api
  rm "$(config_file repos)"
  run_gw link rest-api "$HOME/repos/rest-api"
  assert_exit 0
  assert_file_equals "$(config_file repos)" 'rest-api ~/repos/rest-api'

  run_gw link
  assert_contains "$gw_stdout" 'SERVICE   REPO              BRANCH  HEAD'
  assert_contains "$gw_stdout" "rest-api  ~/repos/rest-api  main    ${$(repo_commit rest-api)[1,8]}"

  run_gw link rm rest-api
  assert_exit 0
  assert_equals '' "$(< "$(config_file repos)")"
}

test_link_accepts_a_relative_path() {
  given_repo rest-api
  rm "$(config_file repos)"
  cd "$HOME/repos"
  run_gw link rest-api rest-api
  assert_file_equals "$(config_file repos)" 'rest-api ~/repos/rest-api'
}

test_link_refuses_a_repo_without_a_deploy_script() {
  mkdir -p "$HOME/repos/plain"
  print -r -- '{ "scripts": {} }' > "$HOME/repos/plain/package.json"
  run_gw link plain "$HOME/repos/plain"
  assert_exit 1
  assert_contains "$gw_stderr" 'No package.json with a deploy script'
}

test_link_relinking_moves_the_service_to_the_new_repo() {
  given_repo rest-api
  given_repo other
  run_gw link rest-api "$HOME/repos/other"
  assert_file_equals "$(config_file repos)" $'other ~/repos/other\nrest-api ~/repos/other'
}

test_target_add_list_and_remove() {
  mkdir -p "$HOME/repos/rest/scripts"
  print -r -- 'td@bravo.local' > "$HOME/repos/rest/scripts/target"
  print -r -- $'A=1\nVITE_PROXY_TARGET=http://td@bravo.local' > "$HOME/repos/rest/.env"

  run_gw target add rest "$HOME/repos/rest/scripts/target"
  assert_exit 0
  run_gw target add rest "$HOME/repos/rest/.env" VITE_PROXY_TARGET
  assert_exit 0
  assert_file_equals "$(config_file targets)" $'rest ~/repos/rest/scripts/target\nrest ~/repos/rest/.env VITE_PROXY_TARGET'

  run_gw target
  assert_contains "$gw_stdout" 'rest  ~/repos/rest/scripts/target  -                  td@bravo.local'
  assert_contains "$gw_stdout" 'rest  ~/repos/rest/.env            VITE_PROXY_TARGET  http://td@bravo.local'

  run_gw target rm rest "$HOME/repos/rest/.env"
  assert_file_equals "$(config_file targets)" 'rest ~/repos/rest/scripts/target'
  run_gw target rm rest
  assert_equals '' "$(< "$(config_file targets)")"
}

test_target_add_refuses_duplicates_and_missing_directories() {
  mkdir -p "$HOME/repos/rest/scripts"
  run_gw target add rest "$HOME/repos/rest/scripts/target"
  assert_exit 0
  assert_contains "$gw_stderr" 'does not exist yet'
  run_gw target add rest "$HOME/repos/rest/scripts/target"
  assert_exit 1
  assert_contains "$gw_stderr" 'Target already exists'
  run_gw target add other "$HOME/nowhere/target"
  assert_exit 1
  assert_contains "$gw_stderr" 'No such directory'
}

test_target_unknown_action_is_a_usage_error() {
  run_gw target frobnicate
  assert_exit 2
  assert_contains "$gw_stderr" 'Unknown action for gw target: frobnicate'
}

test_use_writes_every_target_and_shows_before_and_after() {
  given_alias alpha td@alpha.local
  given_repo rest-api
  print -r -- $'KEEP=1\nVITE_PROXY_TARGET=http://td@old.local\nALSO=2' > "$HOME/repos/rest-api/.env"
  print -r -- 'rest-api ~/repos/rest-api/.env VITE_PROXY_TARGET' >> "$(config_file targets)"

  run_gw use alpha
  assert_exit 0
  assert_file_equals "$HOME/repos/rest-api/scripts/target" 'td@alpha.local'
  assert_file_equals "$HOME/repos/rest-api/.env" $'KEEP=1\nVITE_PROXY_TARGET=http://td@alpha.local\nALSO=2'
  assert_contains "$gw_stdout" 'td@original.local    td@alpha.local'
  assert_contains "$gw_stdout" 'http://td@old.local  http://td@alpha.local'
}

test_use_limits_to_named_targets() {
  given_alias alpha td@alpha.local
  given_repo rest-api
  given_repo frontend
  run_gw use alpha frontend
  assert_file_equals "$HOME/repos/frontend/scripts/target" 'td@alpha.local'
  assert_file_equals "$HOME/repos/rest-api/scripts/target" 'td@original.local'
}

test_use_unknown_target_changes_nothing() {
  given_alias alpha td@alpha.local
  given_repo rest-api
  run_gw use alpha rest-api nosuch
  assert_exit 1
  assert_contains "$gw_stderr" 'Unknown target name: nosuch'
  assert_file_equals "$HOME/repos/rest-api/scripts/target" 'td@original.local'
}

test_use_adds_the_env_line_when_it_is_missing() {
  given_alias alpha td@alpha.local
  mkdir -p "$HOME/repos/frontend"
  print -r -- 'KEEP=1' > "$HOME/repos/frontend/.env"
  print -r -- 'frontend ~/repos/frontend/.env VITE_PROXY_TARGET' > "$(config_file targets)"
  run_gw use alpha
  assert_file_equals "$HOME/repos/frontend/.env" $'KEEP=1\nVITE_PROXY_TARGET=http://td@alpha.local'
}
