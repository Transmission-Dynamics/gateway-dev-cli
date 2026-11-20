GW_COMPLETE_FILES=':files'
GW_COMPLETE_DIRECTORIES=':directories'

gw_complete() {
  if (( $# == 0 )); then
    gw_complete_commands
    return
  fi
  local command=${GW_COMMAND_ALIASES[$1]:-$1} word
  local -a typed=()
  shift
  gw_is_command "$command" || return 0
  while (( $# > 0 )); do
    word=$1
    shift
    if [[ $word != -* ]]; then
      typed+=("$word")
    elif [[ $word != *=* ]] && gw_flag_needs_value "$command" "$word"; then
      (( $# > 0 )) || return 0
      shift
    fi
  done
  gw_complete_flags "$command"
  if (( $+functions[complete_$command] )); then
    "complete_$command" "${typed[@]}"
  fi
}

gw_candidate() {
  print -r -- "$1"$'\t'"${2:-}"
}

gw_complete_commands() {
  local command
  for command in "${GW_COMMANDS[@]}"; do
    gw_candidate "$command" "${GW_SUMMARY[$command]}"
  done
}

gw_complete_flags() {
  local command=$1 line
  local -a names
  for line in "${(@f)GW_FLAGS[$command]}"; do
    [[ -n $line ]] || continue
    names=($(gw_flag_spec_names "${line%%$'\t'*}"))
    gw_candidate "${names[-1]}" "${line#*$'\t'}"
  done
}

gw_complete_gateways() {
  local name address
  gw_config_entries "$GW_ALIASES" | while read -r name address; do
    gw_candidate "$name" "$address"
  done
}

gw_complete_linked_services() {
  local service repo_path
  gw_config_entries "$GW_REPOS" | while read -r service repo_path; do
    gw_candidate "$service" "$repo_path"
  done
}

gw_complete_target_names() {
  local name
  for name in $(gw_config_names "$GW_TARGETS"); do
    gw_candidate "$name" 'target'
  done
}

gw_complete_gateway_then() {
  local following=$1
  shift
  if (( $# == 0 )); then gw_complete_gateways; fi
  [[ -z $following ]] || "$following"
}
