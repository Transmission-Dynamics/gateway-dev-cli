given_installed_gw() {
  "$GW_REPO/install.sh" > /dev/null 2>&1 || fail 'install.sh failed'
  : > "$(config_file aliases)"
  : > "$(config_file repos)"
  : > "$(config_file targets)"
}

run_doctor() {
  PATH=$HOME/.local/bin:$PATH run_gw doctor
}

test_doctor_on_a_good_setup_says_gw_is_ready() {
  given_installed_gw
  given_alias alpha td@alpha.local
  given_repo rest-api
  run_doctor
  assert_exit 0
  assert_contains "$gw_stderr" "✓ gw on your PATH runs $GW_REPO"
  assert_contains "$gw_stderr" '✓ ~/.zshrc loads the shell integration'
  assert_contains "$gw_stderr" '✓ git, npm, ssh are installed'
  assert_contains "$gw_stderr" '✓ rest-api ~/repos/rest-api'
  assert_contains "$gw_stderr" '✓ rest-api ~/repos/rest-api/scripts/target'
  assert_contains "$gw_stderr" '✓ alpha td@alpha.local'
  assert_contains "$gw_stderr" '✓ gw is ready to use'
}

test_doctor_names_each_problem_with_its_fix() {
  given_installed_gw
  given_alias alpha td@alpha.local
  given_alias down td@unreachable.local
  given_alias locked td@nokey.local
  given_repo rest-api
  print -r -- 'frontend ~/repos/frontend' >> "$(config_file repos)"
  mkdir -p "$HOME/repos/notarget"
  git -C "$HOME/repos/notarget" init --quiet
  print -r -- 'notarget ~/repos/notarget' >> "$(config_file repos)"
  print -r -- 'gone ~/repos/rest-api/scripts/missing' >> "$(config_file targets)"
  print -r -- 'proxy ~/repos/rest-api/.env VITE_PROXY_TARGET' >> "$(config_file targets)"
  run_doctor
  assert_exit 1
  assert_contains "$gw_stderr" '✗ frontend: ~/repos/frontend does not exist'
  assert_contains "$gw_stderr" 'Fix: gw link frontend <path to the repo>'
  assert_contains "$gw_stderr" '✗ notarget: no target file inside ~/repos/notarget'
  assert_contains "$gw_stderr" 'Fix: gw target add notarget <file its deploy script reads>'
  assert_contains "$gw_stderr" '✗ gone: ~/repos/rest-api/scripts/missing does not exist'
  assert_contains "$gw_stderr" '! proxy: ~/repos/rest-api/.env does not exist yet'
  assert_contains "$gw_stderr" '✗ down: cannot reach td@unreachable.local (ssh: connect to host td@unreachable.local port 22: Operation timed out)'
  assert_contains "$gw_stderr" '✗ locked: td@nokey.local does not accept your ssh key'
  assert_contains "$gw_stderr" 'Fix: ssh-copy-id td@nokey.local'
  assert_contains "$gw_stderr" '✓ alpha td@alpha.local'
  assert_contains "$gw_stderr" '✗ 5 problems found; fix them with the commands above'
}

test_doctor_without_the_install_says_how_to_install() {
  local -a path_without_gw=()
  local dir
  for dir in "${path[@]}"; do [[ -x $dir/gw ]] || path_without_gw+=("$dir"); done
  PATH=${(j/:/)path_without_gw} run_gw doctor
  assert_exit 1
  assert_contains "$gw_stderr" '✗ gw is not on your PATH'
  assert_contains "$gw_stderr" "Fix: $GW_REPO/install.sh"
  assert_contains "$gw_stderr" 'does not load the shell integration, so gw session cannot work'
  assert_contains "$gw_stderr" '! No gateway is saved'
}

test_doctor_notices_an_install_from_another_folder() {
  given_installed_gw
  sed -i '' "s|$GW_REPO|/old/place/gw|g" "$HOME/.zshrc"
  run_doctor
  assert_contains "$gw_stderr" '✗ ~/.zshrc loads gw from another folder'
}

test_doctor_takes_no_arguments() {
  run_gw doctor alpha
  assert_exit 2
  assert_contains "$gw_stderr" 'gw doctor takes no arguments, not: alpha'
}
