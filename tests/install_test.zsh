test_install_links_the_command_and_adds_one_zshrc_block() {
  print -r -- 'export EDITOR=vim' > "$HOME/.zshrc"
  "$GW_REPO/install.sh" > /dev/null 2>&1 || fail 'install.sh failed'
  assert_equals "$GW_REPO/bin/gw" "$(readlink "$HOME/.local/bin/gw")"
  assert_file_equals "$HOME/.zshrc" $'export EDITOR=vim\n# >>> gw >>>\n'"[[ -r $GW_REPO/shell/gw.zsh ]] && source $GW_REPO/shell/gw.zsh"$'\n# <<< gw <<<'
  assert_file_equals "$(config_file aliases)" "$(< "$GW_REPO/examples/aliases")"
}

test_install_twice_changes_nothing_and_keeps_existing_config() {
  print -r -- 'mine td@mine.local' > "$(config_file aliases)"
  "$GW_REPO/install.sh" > /dev/null 2>&1
  local first=$(< "$HOME/.zshrc")
  "$GW_REPO/install.sh" > /dev/null 2>&1 || fail 'second install.sh failed'
  assert_equals "$first" "$(< "$HOME/.zshrc")"
  assert_file_equals "$(config_file aliases)" 'mine td@mine.local'
}

test_install_keeps_a_file_that_is_not_a_link() {
  mkdir -p "$HOME/.local/bin"
  print -r -- 'old' > "$HOME/.local/bin/gw"
  "$GW_REPO/install.sh" > /dev/null 2>&1
  assert_file_equals "$HOME/.local/bin/gw.before-install" 'old'
}

test_uninstall_removes_the_link_and_the_block_only() {
  print -r -- 'export EDITOR=vim' > "$HOME/.zshrc"
  "$GW_REPO/install.sh" > /dev/null 2>&1
  "$GW_REPO/uninstall.sh" > /dev/null 2>&1 || fail 'uninstall.sh failed'
  assert_missing "$HOME/.local/bin/gw"
  assert_file_equals "$HOME/.zshrc" 'export EDITOR=vim'
  [[ -f $(config_file aliases) ]] || fail 'config was removed'
}

test_shell_integration_makes_sessions_change_the_current_shell() {
  given_alias alpha td@alpha.local
  given_remote_service transceiver 96bd8788
  given_remote_unit transceiver
  local result
  result=$(zsh -f -c '
    source "$1/shell/gw.zsh"
    gw session alpha 2> /dev/null
    print -r -- "session=$GW_SESSION label=$GW_SESSION_LABEL"
    gw status 2> /dev/null | tail -n 1
    gw session nosuch 2> /dev/null
    print -r -- "failed=$? still=$GW_SESSION"
    gw session off 2> /dev/null
    print -r -- "after=${GW_SESSION:-none}"
  ' zsh "$GW_REPO")
  assert_contains "$result" 'session=td@alpha.local label=alpha'
  assert_contains "$result" 'transceiver  96bd8788'
  assert_contains "$result" 'failed=2 still=td@alpha.local'
  assert_contains "$result" 'after=none'
}

test_shell_integration_keeps_an_existing_right_prompt() {
  local result
  result=$(zsh -f -c 'RPROMPT=mine; source "$1/shell/gw.zsh"; source "$1/shell/gw.zsh"; print -r -- "$RPROMPT"' zsh "$GW_REPO")
  assert_equals '%F{yellow}${GW_SESSION:+[gw:$GW_SESSION_LABEL]}%fmine' "$result"
}

test_install_run_with_bash_or_sh_still_keeps_the_zshrc() {
  print -r -- 'export EDITOR=vim' > "$HOME/.zshrc"
  bash "$GW_REPO/install.sh" > /dev/null 2>&1 || fail 'bash install.sh failed'
  sh "$GW_REPO/install.sh" > /dev/null 2>&1 || fail 'sh install.sh failed'
  assert_file_equals "$HOME/.zshrc" $'export EDITOR=vim\n# >>> gw >>>\n'"[[ -r $GW_REPO/shell/gw.zsh ]] && source $GW_REPO/shell/gw.zsh"$'\n# <<< gw <<<'
  bash "$GW_REPO/uninstall.sh" > /dev/null 2>&1 || fail 'bash uninstall.sh failed'
  assert_file_equals "$HOME/.zshrc" 'export EDITOR=vim'
}

test_install_keeps_the_previous_zshrc_next_to_it() {
  print -r -- 'export EDITOR=vim' > "$HOME/.zshrc"
  "$GW_REPO/install.sh" > /dev/null 2>&1
  assert_file_equals "$HOME/.zshrc.before-gw" 'export EDITOR=vim'
}
