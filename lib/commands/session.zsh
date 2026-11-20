gw_command session \
  summary 'Use one gateway for every gw command in this terminal' \
  usage '<gateway> [target...]' 'Start a session, or switch it to another gateway' \
  usage '' 'Show the current session' \
  usage 'off' 'End the session' \
  note 'While a session is active the gateway argument of every other command is optional.' \
  note 'A session only sets environment variables in this terminal; target files stay as they are.' \
  note 'Targets with an ENV_VAR are exported too, so npm run dev follows the session.' \
  note 'Name targets to limit which of those variables are exported.' \
  example 'gw session alpha' \
  example 'gw session bravo frontend' \
  example 'gw session off'

GW_SESSION_VARIABLES=(GW_SESSION GW_SESSION_LABEL GW_SESSION_NAMES GW_SESSION_ENV_VARS)

cmd_session() {
  gw_parse_arguments session "$@"
  if [[ -t 1 ]]; then
    gw_error 'gw session needs the gw shell integration to change this terminal.'
    gw_hint 'Set it up with:' "$(gw_shorten_path "$GW_ROOT")/install.sh"
    gw_note 'Then open a new terminal.'
    exit 1
  fi
  set -- "${gw_arguments[@]}"
  if (( $# == 0 )); then
    session_show
  elif [[ $1 == off ]]; then
    (( $# == 1 )) || gw_usage_error session 'gw session off takes no further arguments.'
    session_end
  else
    session_start "$@"
  fi
}

complete_session() {
  if (( $# == 0 )); then
    gw_candidate off 'End the session'
    gw_complete_gateways
  elif [[ $1 != off ]]; then
    gw_complete_target_names
  fi
}

session_print_unset() {
  print -r -- "unset ${GW_SESSION_VARIABLES[*]} ${GW_SESSION_ENV_VARS:-}"
}

session_show() {
  if [[ -z ${GW_SESSION:-} ]]; then
    gw_note 'No session is active.'
    gw_hint 'Start one with:' 'gw session <gateway>'
    return
  fi
  session_describe "${GW_SESSION_LABEL:-$GW_SESSION}" "$GW_SESSION" "${GW_SESSION_NAMES:-}"
}

session_end() {
  if [[ -z ${GW_SESSION:-} ]]; then
    gw_note 'No session is active.'
    return
  fi
  session_print_unset
  gw_ok "Session ended ${E[muted]}(was ${GW_SESSION_LABEL:-$GW_SESSION})${E[reset]}"
}

session_start() {
  local label=$1 address name target_path env_var proxy
  local -a env_vars=()
  shift
  gw_require_gateway_argument "$label"
  gw_require_target_names "$@"
  address=$(gw_gateway_address "$label")
  proxy=$(gw_proxy_value "$address")

  gw_selected_targets "$@" | while IFS=$'\t' read -r name target_path env_var; do
    if [[ -n $env_var ]] && (( ! ${env_vars[(Ie)$env_var]} )); then
      env_vars+=("$env_var")
    fi
  done

  session_print_unset
  print -r -- "export GW_SESSION=${(q)address}"
  print -r -- "export GW_SESSION_LABEL=${(q)label}"
  print -r -- "export GW_SESSION_NAMES=${(q)${(j: :)@}}"
  print -r -- "export GW_SESSION_ENV_VARS=${(q)${(j: :)env_vars}}"
  for env_var in "${env_vars[@]}"; do
    print -r -- "export $env_var=${(q)proxy}"
  done

  session_describe "$label" "$address" "${(j: :)@}"
  for env_var in "${env_vars[@]}"; do
    gw_info "  ${E[variable]}$env_var${E[reset]}${E[muted]}=${E[reset]}$proxy"
  done
  gw_hint 'End it with:' 'gw session off'
}

session_describe() {
  local label=$1 address=$2 names=$3
  gw_info "${E[muted]}Session:${E[reset]} ${E[bold]}${E[yellow]}$label${E[reset]} ${E[muted]}→${E[reset]} ${E[address]}$address${E[reset]}${names:+ ${E[muted]}(targets: $names)${E[reset]}}"
}
