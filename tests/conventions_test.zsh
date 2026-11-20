repo_zsh_files() {
  print -l "$GW_REPO"/bin/gw "$GW_REPO"/*.sh "$GW_REPO"/lib/**/*.zsh "$GW_REPO"/shell/*.zsh "$GW_REPO"/tests/run "$GW_REPO"/tests/*.zsh
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

test_conventions_code_has_no_comments() {
  local file found
  for file in $(repo_zsh_files) $(repo_sh_files) "$GW_REPO"/examples/*; do
    found=$(awk 'NR == 1 && /^#!/ { next } /^[[:space:]]*#/ { print FILENAME ":" NR ": " $0 }' "$file")
    [[ -z $found ]] || fail "comment found, say it with names instead: ${found#$GW_REPO/}"
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
