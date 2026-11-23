GW_SPINNER_FRAMES=(⠋ ⠙ ⠹ ⠸ ⠼ ⠴ ⠦ ⠧ ⠇ ⠏)
GW_PROGRESS_PREFIX='progress: '
GW_FAILURE_TAIL_LINES=25
GW_STEP_INDENT='    '

typeset -g gw_temp_dir='' gw_spinner_pid='' gw_remote_output=''
typeset -gi GW_VERBOSE=0

gw_temp_root() {
  print -r -- "${${TMPDIR:-/tmp}%/}"
}

gw_temp_file() {
  if [[ -z $gw_temp_dir ]]; then
    gw_temp_dir=$(mktemp -d "$(gw_temp_root)/gw.XXXXXX")
    gw_on_exit gw_remove_temp_dir
  fi
  REPLY=$(mktemp "$gw_temp_dir/XXXXXX")
}

gw_remove_temp_dir() {
  [[ -z $gw_temp_dir ]] || rm -rf "$gw_temp_dir"
  gw_temp_dir=''
}

gw_elapsed() {
  local seconds=$(( SECONDS - $1 ))
  if (( seconds >= 60 )); then
    printf '%dm %02ds\n' $(( seconds / 60 )) $(( seconds % 60 ))
  else
    printf '%ds\n' "$seconds"
  fi
}

gw_in_dir() {
  local directory=$1
  shift
  (cd "$directory" && "$@")
}

gw_spinner_start() {
  local indent=$1 label=$2 log=$3
  [[ -t 2 ]] || return 0
  gw_spinner_loop "$indent" "$label" "$log" "$SECONDS" "$(tput cols 2> /dev/null || print 100)" &
  gw_spinner_pid=$!
  gw_on_exit gw_spinner_stop
}

gw_spinner_loop() {
  local indent=$1 label=$2 log=$3 started=$4 columns=$5
  local frame=0 latest elapsed room
  while true; do
    latest=$(tail -n 1 "$log" 2> /dev/null | tr -d '\r' | sed $'s/\e\\[[0-9;]*[A-Za-z]//g') || latest=''
    latest=${latest#$GW_PROGRESS_PREFIX}
    elapsed=$(gw_elapsed "$started")
    room=$(( columns - ${#indent} - ${#label} - ${#elapsed} - 12 ))
    if (( room > 0 )) && [[ -n $latest ]]; then
      latest="  · ${latest[1,room]}"
    else
      latest=''
    fi
    print -n -u2 -r -- $'\r\e[K'"$indent${E[command]}${GW_SPINNER_FRAMES[frame % ${#GW_SPINNER_FRAMES} + 1]}${E[reset]} $label  ${E[caution]}$elapsed${E[reset]}${E[muted]}$latest${E[reset]}"
    frame=$(( frame + 1 ))
    sleep 0.2
  done
}

gw_spinner_stop() {
  [[ -n $gw_spinner_pid ]] || return 0
  kill "$gw_spinner_pid" 2> /dev/null || true
  wait "$gw_spinner_pid" 2> /dev/null || true
  gw_spinner_pid=''
  print -n -u2 -- $'\r\e[K'
}

gw_step_done() {
  print -u2 -r -- "$GW_STEP_INDENT${E[good]}${I[ok]}${E[reset]} $1${2:+ ${E[muted]}($2)${E[reset]}}"
}

gw_run_step() {
  local label=$1 started=$SECONDS exit_code=0 log=''
  shift
  if (( GW_VERBOSE )); then
    print -u2 -r -- "$GW_STEP_INDENT${E[command]}${I[step]}${E[reset]} $label"
    "$@" < /dev/null >&2 || exit_code=$?
  else
    gw_temp_file
    log=$REPLY
    [[ -t 2 ]] || print -u2 -r -- "$GW_STEP_INDENT${E[muted]}… $label${E[reset]}"
    gw_spinner_start "$GW_STEP_INDENT" "$label" "$log"
    "$@" < /dev/null > "$log" 2>&1 || exit_code=$?
    gw_spinner_stop
  fi
  if (( exit_code == 0 )); then
    gw_step_done "$label" "$(gw_elapsed "$started")"
    return 0
  fi
  print -u2 -r -- "$GW_STEP_INDENT${E[bad]}${I[error]} $label failed${E[reset]} ${E[muted]}after $(gw_elapsed "$started")${E[reset]}"
  [[ -z $log ]] || gw_show_failed_log "$log"
  return $exit_code
}

gw_show_failed_log() {
  local log=$1 kept
  kept=$(mktemp "$(gw_temp_root)/gw-failed.XXXXXX")
  cp "$log" "$kept"
  tail -n "$GW_FAILURE_TAIL_LINES" "$log" | gw_quote_lines "$GW_STEP_INDENT"
  gw_hint "${GW_STEP_INDENT}Full output:" "$kept"
}

gw_remote() {
  local label=$1 script=$2 exit_code=0 output_file error_file line
  shift 2
  gw_temp_file
  output_file=$REPLY
  gw_temp_file
  error_file=$REPLY

  gw_prepare_ssh
  gw_spinner_start '' "$label" "$error_file"
  ssh -o BatchMode=yes "${GW_SSH_OPTIONS[@]}" "$gw_gateway" sh -s -- "${(@qq)@}" \
    < "$GW_ROOT/lib/remote/$script.sh" > "$output_file" 2> "$error_file" || exit_code=$?
  gw_spinner_stop

  gw_remote_output=$(< "$output_file")
  (( exit_code != 0 )) || return 0

  if (( exit_code == 255 )); then
    gw_error "Cannot reach $gw_gateway over ssh."
    gw_quote_lines < "$error_file"
    gw_hint 'Check the connection with:' "ssh $gw_gateway"
    return $exit_code
  fi
  while IFS= read -r line; do
    [[ -z $line || $line == "$GW_PROGRESS_PREFIX"* ]] || gw_error "$line"
  done < "$error_file"
  return $exit_code
}

gw_require_reachable() {
  gw_remote "Connecting to $gw_gateway" ping || exit 1
}

gw_watch() {
  local seconds=${GW_WATCH_SECONDS:-$1} fetch=$2 show=$3 frame end_of_line=$'\e[K\n'
  TRAPINT() { gw_stop_watching }
  TRAPTERM() { gw_stop_watching }
  [[ ! -t 1 ]] || print -n -- $'\e[H\e[2J'
  while true; do
    if [[ -t 1 ]]; then
      if "$fetch"; then
        frame=$({ gw_announce_gateway; "$show"; gw_note "Refreshing every ${seconds}s, Ctrl+C to stop"; } 2>&1) || true
        print -n -r -- $'\e[H'"${frame//$'\n'/$end_of_line}"$'\e[K\n\e[J'
      fi
    else
      "$fetch" && "$show"
      gw_note "Refreshing every ${seconds}s, Ctrl+C to stop"
    fi
    sleep "$seconds" || true
  done
}

gw_stop_watching() {
  print -u2 2>&$GW_STDERR_FD
  exit 0
}
