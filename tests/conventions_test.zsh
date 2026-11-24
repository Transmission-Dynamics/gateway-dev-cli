repo_zsh_files() {
  print -l "$GW_REPO"/bin/gw "$GW_REPO"/*.sh "$GW_REPO"/scripts/*.sh "$GW_REPO"/lib/**/*.zsh "$GW_REPO"/shell/*.zsh "$GW_REPO"/tests/run "$GW_REPO"/tests/*.zsh
}

repo_sh_files() {
  print -l "$GW_REPO"/lib/remote/*.sh "$GW_REPO"/tests/fakes/*/*
}

test_conventions_every_script_parses() {
  local file
  for file in $(repo_zsh_files); do
    zsh -n "$file" || fail "zsh syntax error in ${file#$GW_REPO/}"
  done
  for file in $(repo_sh_files); do
    sh -n "$file" || fail "sh syntax error in ${file#$GW_REPO/}"
  done
}

test_conventions_every_command_has_help_and_is_documented() {
  local command
  run_gw __complete
  for command in ${(f)"$(print -r -- "$gw_stdout" | cut -f1)"}; do
    run_gw "$command" --help
    assert_exit 0
    [[ -n ${gw_stdout}${gw_stderr} ]] || fail "gw $command --help prints nothing"
    grep -q "gw $command" "$GW_REPO/README.md" || fail "gw $command is missing from README.md"
  done
}

test_conventions_remote_scripts_only_use_the_apps_dir_variable() {
  local found
  found=$(grep -n '/usr/jrd' "$GW_REPO"/lib/remote/*.sh | grep -v 'GW_APPS_DIR:-/usr/jrd' || true)
  [[ -z $found ]] || fail "hard-coded /usr/jrd in a remote script: $found"
}

status_script_states() {
  local script=$GW_REPO/lib/remote/status.sh
  {
    grep -oE "state ?= ?[\"'][^\"']+[\"']" "$script"
    grep -oE '\? "[^"]+" : "[^"]+"' "$script" | tr ':' '\n'
  } | grep -oE "[\"'][^\"']+[\"']" | tr -d "\"'" | sort -u
}

test_conventions_every_status_state_is_explained() {
  local state
  source "$GW_REPO/lib/status.zsh"
  local -A explained=("${GW_STATES[@]}")
  for state in ${(f)"$(status_script_states)"}; do
    [[ $state == 'no unit' ]] && continue
    (( ${+explained[$state]} )) || fail "state '$state' from lib/remote/status.sh has no entry in GW_STATES"
  done
}
