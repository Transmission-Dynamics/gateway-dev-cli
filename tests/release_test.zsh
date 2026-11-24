given_release() {
  local version=$1 stage=$GW_TEST_DIR/stage/gw-$1
  mkdir -p "$stage" "$GW_TEST_DIR/release"
  print -r -- "$version" > "$stage/VERSION"
  print -r -- $'#!/usr/bin/env zsh\nprint -r -- "${0:A:h}" > "$GW_TEST_DIR/installed-from"' > "$stage/install.sh"
  chmod +x "$stage/install.sh"
  tar -czf "$GW_TEST_DIR/release/gw-$version.tar.gz" -C "$GW_TEST_DIR/stage" "gw-$version"
}

run_get() {
  gw_exit=0
  GW_INSTALL_DIR=$HOME/.local/share/gw zsh "$GW_REPO/get.sh" "$@" > "$GW_TEST_DIR/stdout" 2> "$GW_TEST_DIR/stderr" < /dev/null || gw_exit=$?
  gw_stderr=$(< "$GW_TEST_DIR/stderr")
}

test_get_installs_the_latest_release_and_removes_older_ones() {
  mkdir -p "$HOME/.local/share/gw/v0.0.1"
  given_release v1.2.3
  run_get
  assert_exit 0
  assert_file_equals "$GW_TEST_DIR/installed-from" "$HOME/.local/share/gw/v1.2.3"
  assert_missing "$HOME/.local/share/gw/v0.0.1"
  assert_contains "$(< "$GW_TEST_DIR/gh.log")" 'gh release download --repo Transmission-Dynamics/gateway-dev-cli --pattern gw-*.tar.gz'
}

test_get_installs_the_version_asked_for() {
  given_release v1.0.0
  run_get v1.0.0
  assert_exit 0
  assert_contains "$(< "$GW_TEST_DIR/gh.log")" 'gh release download v1.0.0 --repo'
}

test_get_without_a_github_login_says_how_to_sign_in() {
  GW_TEST_GH_SIGNED_OUT=1 GITHUB_TOKEN='' run_get
  assert_exit 1
  assert_contains "$gw_stderr" 'is private, so sign in to GitHub first'
  assert_contains "$gw_stderr" 'gh auth login'
}

test_package_adds_the_version_and_leaves_out_development_files() {
  local archive listing
  archive=$(GW_DIST_DIR=$GW_TEST_DIR/dist "$GW_REPO/scripts/package.sh" v1.2.3 2> /dev/null) || fail 'package.sh failed'
  listing=$(tar -tzf "$archive")
  assert_contains "$listing" 'gw-v1.2.3/VERSION'
  assert_contains "$listing" 'gw-v1.2.3/bin/gw'
  assert_lacks "$listing" 'gw-v1.2.3/tests/'
  assert_lacks "$listing" 'gw-v1.2.3/.github/'
  assert_equals v1.2.3 "$(tar -xzOf "$archive" gw-v1.2.3/VERSION)"
}

test_package_rejects_a_version_that_is_not_a_tag() {
  GW_DIST_DIR=$GW_TEST_DIR/dist "$GW_REPO/scripts/package.sh" latest > /dev/null 2>&1 && fail 'package.sh accepted latest'
  assert_missing "$GW_TEST_DIR/dist"
}

test_installed_release_reports_its_version_and_updates_with_get() {
  local copy=$GW_TEST_DIR/installed
  mkdir -p "$copy"
  cp -R "$GW_REPO/bin" "$GW_REPO/lib" "$copy/"
  print -r -- v1.2.3 > "$copy/VERSION"
  print -r -- 'print -r -- "get $*"' > "$copy/get.sh"
  assert_equals 'gw v1.2.3' "$("$copy/bin/gw" --version)"
  assert_equals 'get v2.0.0' "$("$copy/bin/gw" update v2.0.0 2> /dev/null)"
}

test_update_from_a_clone_points_to_git_pull() {
  run_gw update
  assert_exit 1
  assert_contains "$gw_stderr" 'runs from a git clone'
  assert_contains "$gw_stderr" 'pull'
}
