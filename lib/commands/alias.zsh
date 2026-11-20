gw_command alias \
  summary 'Save short names for gateway addresses' \
  usage '' 'List saved aliases' \
  usage '<address> <name>' 'Save a short name for a gateway' \
  usage 'rm <name>' 'Remove an alias' \
  note 'Names may contain letters, digits, - and _.' \
  example 'gw alias td@alpha.local alpha' \
  example 'gw alias rm alpha'

GW_RESERVED_ALIAS_NAMES=(off rm)

cmd_alias() {
  gw_parse_arguments alias "$@"
  set -- "${gw_arguments[@]}"
  if (( $# == 0 )); then
    alias_list
  elif [[ $1 == rm && $# == 2 ]]; then
    alias_remove "$2"
  elif [[ $1 != rm && $# == 2 ]]; then
    alias_add "$1" "$2"
  else
    gw_usage_error alias 'Expected an address and a name, or rm and a name.'
  fi
}

complete_alias() {
  if (( $# == 0 )); then
    gw_candidate rm 'Remove an alias'
  elif [[ $1 == rm && $# == 1 ]]; then
    gw_complete_gateways
  fi
}

alias_list() {
  if [[ -z $(gw_alias_names) ]]; then
    gw_hint 'No aliases yet. Save one with:' 'gw alias <address> <name>'
    return
  fi
  {
    printf 'NAME\tADDRESS\n'
    gw_config_entries "$GW_ALIASES" | awk '{ printf "%s\t%s\n", $1, $2 }'
  } | gw_table alias_style_cell
}

alias_style_cell() {
  case $1 in
    1) REPLY=${C[service]} ;;
    2) REPLY=${C[commit]} ;;
  esac
}

alias_add() {
  local address=$1 name=$2
  [[ $name =~ '^[A-Za-z0-9_-]+$' ]] ||
    gw_die "An alias name may only contain letters, digits, - and _: $name"
  (( ! ${GW_RESERVED_ALIAS_NAMES[(Ie)$name]} )) ||
    gw_die "An alias cannot be named $name, gw uses that word itself"
  ! gw_config_has "$GW_REPOS" "$name" ||
    gw_die "$name is already a linked service, pick another alias name"
  [[ $address != *[[:space:]]* ]] || gw_die "An address cannot contain spaces: $address"

  gw_config_remove "$GW_ALIASES" "$name"
  gw_config_append "$GW_ALIASES" "$name $address"
  gw_config_sort "$GW_ALIASES"
  gw_ok "${E[service]}$name${E[reset]} ${E[muted]}→${E[reset]} ${E[commit]}$address${E[reset]}"
}

alias_remove() {
  local name=$1
  gw_is_alias "$name" || gw_die "No alias named: $name"
  gw_config_remove "$GW_ALIASES" "$name"
  gw_ok "Removed alias ${E[service]}$name${E[reset]}"
}
