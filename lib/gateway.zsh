GW_SSH_CONTROL_DIR=${XDG_CACHE_HOME:-$HOME/.cache}/gw
GW_SSH_OPTIONS=(
  -o ConnectTimeout=10
  -o ServerAliveInterval=5
  -o ServerAliveCountMax=2
  -o ControlMaster=auto
  -o "ControlPath=$GW_SSH_CONTROL_DIR/ssh-%C"
  -o ControlPersist=60
)

gw_prepare_ssh() {
  [[ -d $GW_SSH_CONTROL_DIR ]] || mkdir -p -m 700 "$GW_SSH_CONTROL_DIR" 2> /dev/null || true
}

typeset -g gw_gateway=''

gw_alias_names() {
  gw_config_names "$GW_ALIASES"
}

gw_is_alias() {
  gw_config_has "$GW_ALIASES" "$1"
}

gw_looks_like_address() {
  [[ $1 == *@* || $1 == *.* ]]
}

gw_is_gateway() {
  gw_is_alias "$1" || gw_looks_like_address "$1"
}

gw_gateway_address() {
  gw_config_lookup "$GW_ALIASES" "$1" || print -r -- "$1"
}

typeset -g gw_gateway_word=''

gw_announce_gateway() {
  gw_info "${I[gateway]:+${I[gateway]} }${E[muted]}Gateway:${E[reset]} ${E[address]}$gw_gateway${E[reset]}${1:+ ${E[caution]}$1${E[reset]}}"
}

gw_take_gateway() {
  local command=$1 spelling=${2:-checked} first=${gw_arguments[1]:-}
  if [[ -n $first ]] && gw_is_gateway "$first"; then
    gw_gateway=$(gw_gateway_address "$first")
    gw_gateway_word=$first
    shift gw_arguments
    gw_announce_gateway
    return
  fi
  if [[ -n $first && $spelling == checked ]]; then
    gw_reject_misspelled_alias "$first"
  fi
  gw_use_session_gateway "$command"
}

gw_use_session_gateway() {
  local command=$1
  if [[ -n ${GW_SESSION:-} ]]; then
    gw_gateway=$GW_SESSION
    gw_announce_gateway '(session)'
    return
  fi
  gw_error 'No gateway given and no session is active.'
  gw_hint 'Name one:' "gw $command <gateway> ..."
  gw_hint 'Or start a session:' 'gw session <gateway>'
  gw_list_saved_gateways
  exit 2
}

gw_list_saved_gateways() {
  local -a names=($(gw_alias_names))
  if (( ${#names} > 0 )); then
    gw_note "Saved gateways: ${(j:, :)names}"
  else
    gw_hint 'Save a short name with:' 'gw alias <address> <name>'
  fi
}

gw_reject_misspelled_alias() {
  local word=$1
  ! gw_config_has "$GW_REPOS" "$word" || return 0
  gw_closest "$word" $(gw_alias_names)
  [[ -n $REPLY ]] || return 0
  gw_error "Unknown gateway: $word"
  gw_hint 'Did you mean:' "$REPLY"
  exit 2
}

gw_require_gateway_argument() {
  local word=$1
  ! gw_is_gateway "$word" || return 0
  gw_error "Not a saved alias or an ssh address: $word"
  gw_closest_or_prefix "$word" $(gw_alias_names)
  [[ -z $REPLY ]] || gw_hint 'Did you mean:' "$REPLY"
  gw_list_saved_gateways
  exit 2
}

gw_interactive_ssh() {
  local exit_code=0
  gw_prepare_ssh
  ssh "${GW_SSH_OPTIONS[@]}" "$@" || exit_code=$?
  if (( exit_code == 255 )); then
    gw_error "Cannot reach $gw_gateway over ssh."
    gw_hint 'Check the connection with:' "ssh $gw_gateway"
  fi
  exit $exit_code
}
