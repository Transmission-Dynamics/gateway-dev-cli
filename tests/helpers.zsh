zmodload zsh/datetime

GW_BIN=$GW_REPO/bin/gw
FIXED_NOW='Mon 2026-11-02 10:13:15 UTC'
FIXED_NOW_PLUS_20H_05M=1793686695

typeset -g gw_stdout='' gw_stderr='' gw_output='' gw_exit=0

run_test() {
  local test_name=$1 sandbox exit_code=0
  sandbox=$(mktemp -d "${${TMPDIR:-/tmp}%/}/gw-test.XXXXXX")
  sandbox=${sandbox:A}
  ( sandbox_enter "$sandbox" && "$test_name" ) || exit_code=$?
  rm -rf "$sandbox"
  return $exit_code
}

sandbox_enter() {
  export GW_TEST_DIR=$1
  export GW_TEST_FAKES=$TESTS_DIR/fakes
  export HOME=$GW_TEST_DIR/home
  export XDG_CONFIG_HOME=$HOME/.config
  export TMPDIR=$GW_TEST_DIR/tmp
  export PATH=$GW_TEST_FAKES/local:$PATH
  export GIT_CONFIG_GLOBAL=$GW_TEST_DIR/gitconfig
  export GIT_CONFIG_NOSYSTEM=1
  export GW_COLOR=never
  export GW_TEST_NOW=$FIXED_NOW_PLUS_20H_05M
  unset NO_COLOR GW_SESSION GW_SESSION_LABEL GW_SESSION_NAMES GW_SESSION_ENV_VARS VITE_PROXY_TARGET ZDOTDIR
  mkdir -p "$HOME" "$XDG_CONFIG_HOME/gw" "$TMPDIR" "$GW_TEST_DIR/jrd" "$GW_TEST_DIR/units"
  git config --global user.name 'Test User'
  git config --global user.email 'test@example.com'
  git config --global init.defaultBranch main
  git config --global advice.detachedHead false
  cd "$HOME"
}

run_gw() {
  gw_exit=0
  "$GW_BIN" "$@" > "$GW_TEST_DIR/stdout" 2> "$GW_TEST_DIR/stderr" < /dev/null || gw_exit=$?
  gw_stdout=$(< "$GW_TEST_DIR/stdout")
  gw_stderr=$(< "$GW_TEST_DIR/stderr")
  gw_output=$gw_stdout$'\n'$gw_stderr
}

fail() {
  print -r -- "$1"
  if [[ -n ${gw_output//$'\n'} ]]; then
    print -r -- "--- exit code $gw_exit, stdout:"
    print -r -- "$gw_stdout"
    print -r -- "--- stderr:"
    print -r -- "$gw_stderr"
  fi
  exit 1
}

assert_exit() {
  (( gw_exit == $1 )) || fail "expected exit code $1, got $gw_exit"
}

assert_equals() {
  [[ $1 == "$2" ]] || fail "expected: $1"$'\n'"     got: $2"
}

assert_contains() {
  [[ $1 == *"$2"* ]] || fail "expected to find: $2"$'\n'"in: $1"
}

assert_lacks() {
  [[ $1 != *"$2"* ]] || fail "expected not to find: $2"$'\n'"in: $1"
}

assert_file_equals() {
  local file=$1 expected=$2
  [[ -f $file ]] || fail "missing file: $file"
  assert_equals "$expected" "$(< "$file")"
}

assert_missing() {
  [[ ! -e $1 ]] || fail "expected not to exist: $1"
}

assert_line_order() {
  local text=$1 first=$2 second=$3
  local before=${text%%"$second"*}
  [[ $text == *"$second"* && $before == *"$first"* ]] || fail "expected '$first' before '$second' in: $text"
}

config_file() {
  print -r -- "$XDG_CONFIG_HOME/gw/$1"
}

given_alias() {
  print -r -- "$1 $2" >> "$(config_file aliases)"
}

given_remote_service() {
  local service=$1 commit=$2 deployed_at=${3:-202611021013}
  mkdir -p "$GW_TEST_DIR/jrd/$service"
  print -r -- "$commit" > "$GW_TEST_DIR/jrd/$service/version"
  TZ=UTC touch -t "$deployed_at" "$GW_TEST_DIR/jrd/$service/version"
}

given_remote_unit() {
  local service=$1
  shift
  local -A properties=(
    LoadState loaded ActiveState active SubState running Type simple
    UnitFileState enabled ActiveEnterTimestamp "$FIXED_NOW"
  )
  local property
  for property in "$@"; do
    properties[${property%%=*}]=${property#*=}
  done
  for property in ${(k)properties}; do
    print -r -- "$property=${properties[$property]}"
  done > "$GW_TEST_DIR/units/td-$service.service"
}

given_remote_manifest() {
  local service=$1
  mkdir -p "$GW_TEST_DIR/jrd/$service"
  cat > "$GW_TEST_DIR/jrd/$service/manifest.json"
}

given_repo() {
  local service=$1 repo=$HOME/repos/$1
  mkdir -p "$repo/scripts"
  git -C "$repo" init --quiet
  print -r -- '{ "scripts": { "deploy": "echo deploy" } }' > "$repo/package.json"
  print -r -- '{}' > "$repo/package-lock.json"
  print -r -- "$service" > "$repo/.service-name"
  print -r -- 'scripts/target' > "$repo/.gitignore"
  print -r -- 'td@original.local' > "$repo/scripts/target"
  git -C "$repo" add --all
  git -C "$repo" commit --quiet --message 'First commit'
  print -r -- "$service ~/repos/$service" >> "$(config_file repos)"
  print -r -- "$service ~/repos/$service/scripts/target" >> "$(config_file targets)"
}

repo_commit() {
  git -C "$HOME/repos/$1" rev-parse "${2:-HEAD}"
}

given_second_commit() {
  local repo=$HOME/repos/$1
  print -r -- 'change' > "$repo/change.txt"
  git -C "$repo" add --all
  git -C "$repo" commit --quiet --message 'Second commit'
}

ssh_log() {
  cat "$GW_TEST_DIR/ssh.log" 2> /dev/null
}

npm_log() {
  cat "$GW_TEST_DIR/npm.log" 2> /dev/null
}

given_last_device() {
  local uuid=$1 type=$2 rssi=$3 seconds_ago=$4 battery=${5:-3.0} temperature=${6:-21.5}
  local tables=$GW_TEST_DIR/tables timestamp
  timestamp=$(date -u -r $(( EPOCHSECONDS - seconds_ago )) '+%Y-%m-%dT%H:%M:%S.000Z')
  mkdir -p "$tables"
  sqlite3 "$tables/last-device.db" "
    CREATE TABLE IF NOT EXISTS collection (id INTEGER PRIMARY KEY AUTOINCREMENT, doc TEXT);
    INSERT INTO collection (doc) VALUES (json_object(
      'timestamp', '$timestamp', 'uuid', '$uuid', 'type', '$type', 'rssi', $rssi,
      'temperature', $temperature, 'batteryVoltage', $battery));
  "
}

given_pending_task() {
  print -r -- "$1"$'\t'"$2" >> "$GW_TEST_DIR/tasks"
}

given_gateway_health() {
  local uptime=${1:-78000} available_kb=${2:-750000}
  mkdir -p "$GW_TEST_DIR/proc"
  print -r -- "$uptime.02 275857.90" > "$GW_TEST_DIR/proc/uptime"
  print -r -- '0.88 0.68 0.60 1/414 2696525' > "$GW_TEST_DIR/proc/loadavg"
  print -r -- $'MemTotal:        2000000 kB\nMemFree:          100000 kB\nMemAvailable:     '"$available_kb"' kB' > "$GW_TEST_DIR/proc/meminfo"
}
