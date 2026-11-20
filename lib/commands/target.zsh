gw_command target \
  alias targets \
  summary 'Manage the local files that point repos at a gateway' \
  usage '' 'List target files and the gateway each one holds now' \
  usage 'add <name> <path> [ENV_VAR]' 'Add a target file' \
  usage 'rm <name> [path]' 'Remove a target, or one file of it' \
  note 'Without ENV_VAR the whole file is the address, as in scripts/target.' \
  note 'With ENV_VAR only the line ENV_VAR=http://<address> is set, as in .env.' \
  note 'Files that share a name switch together.' \
  example 'gw target add rest ~/repos/td1023-rest/scripts/target' \
  example 'gw target add frontend ~/repos/td1023-frontend-react/.env VITE_PROXY_TARGET' \
  example 'gw target rm frontend'

cmd_target() {
  gw_parse_arguments target "$@"
  set -- "${gw_arguments[@]}"
  local action=${1:-list}
  (( $# == 0 )) || shift
  case $action in
    list)
      (( $# == 0 )) || gw_usage_error target 'gw target list takes no arguments.'
      target_list
      ;;
    add)
      (( $# == 2 || $# == 3 )) || gw_usage_error target 'gw target add needs a name and a path.'
      target_add "$@"
      ;;
    rm)
      (( $# == 1 || $# == 2 )) || gw_usage_error target 'gw target rm needs a name.'
      target_remove "$@"
      ;;
    *)
      gw_usage_error target "Unknown action for gw target: $action"
      ;;
  esac
}

complete_target() {
  if (( $# == 0 )); then
    gw_candidate add 'Add a target file'
    gw_candidate rm 'Remove a target'
  elif (( $# == 1 )); then
    gw_complete_target_names
  elif [[ $1 == add && $# == 2 ]]; then
    print -r -- "$GW_COMPLETE_FILES"
  fi
}

target_list() {
  if [[ -z $(gw_config_names "$GW_TARGETS") ]]; then
    gw_hint 'No targets yet. Add one with:' 'gw target add <name> <path> [ENV_VAR]'
    return
  fi
  local name target_path env_var
  {
    printf 'NAME\tPATH\tENV VAR\tCURRENT\n'
    gw_config_entries "$GW_TARGETS" | while read -r name target_path env_var; do
      printf '%s\t%s\t%s\t%s\n' "$name" "$target_path" "${env_var:--}" \
        "$(gw_read_target "$(gw_expand_path "$target_path")" "$env_var")"
    done
  } | gw_table target_style_cell
}

target_style_cell() {
  case $1 in
    1) REPLY=${C[service]} ;;
    3) REPLY=${C[variable]} ;;
    4) REPLY=${C[commit]} ;;
  esac
}

target_add() {
  local name=$1 env_var=${3:-} target_file target_path
  target_file=$(gw_expand_path "$2")
  target_file=${target_file:a}
  target_path=$(gw_shorten_path "$target_file")

  [[ $name != *[[:space:]]* && $name != \#* ]] ||
    gw_die "A target name cannot contain spaces or start with #: $name"
  [[ -z $env_var || $env_var =~ '^[A-Za-z_][A-Za-z0-9_]*$' ]] ||
    gw_die "Not a valid environment variable name: $env_var"
  ! gw_config_has "$GW_TARGETS" "$name" "$target_path" ||
    gw_die "Target already exists: $name $target_path"
  [[ -d ${target_file:h} ]] || gw_die "No such directory: $(gw_shorten_path "${target_file:h}")"
  [[ -f $target_file ]] || gw_warn "$target_path does not exist yet, gw use will create it"

  gw_config_append "$GW_TARGETS" "$name $target_path${env_var:+ $env_var}"
  gw_ok "Added ${E[service]}$name${E[reset]} ${E[muted]}→${E[reset]} $target_path${env_var:+ ${E[variable]}($env_var)${E[reset]}}"
}

target_remove() {
  local name=$1 target_path=''
  if (( $# == 2 )); then
    target_path=$(gw_expand_path "$2")
    target_path=$(gw_shorten_path "${target_path:a}")
  fi
  gw_config_has "$GW_TARGETS" "$name" "$target_path" ||
    gw_die "No target matched: $name${target_path:+ $target_path}"
  gw_config_remove "$GW_TARGETS" "$name" "$target_path"
  gw_ok "Removed target ${E[service]}$name${E[reset]}${target_path:+ $target_path}"
}
