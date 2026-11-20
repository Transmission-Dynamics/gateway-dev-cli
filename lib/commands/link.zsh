gw_command link \
  summary 'Choose the local repo each service is deployed from' \
  usage '' 'List linked services with their repo, branch and HEAD' \
  usage '<service> <path>' 'Link a gateway service to the repo gw deploy builds it from' \
  usage 'rm <service>' 'Unlink a service' \
  note 'The service name is the folder name in /usr/jrd on the gateway, for example rest-api.' \
  note 'The repo needs a package.json with a deploy script.' \
  example 'gw link rest-api ~/repos/td1023-rest' \
  example 'gw link rm rest-api'

cmd_link() {
  gw_parse_arguments link "$@"
  set -- "${gw_arguments[@]}"
  if (( $# == 0 )); then
    link_list
  elif [[ $1 == rm && $# == 2 ]]; then
    link_remove "$2"
  elif [[ $1 != rm && $# == 2 ]]; then
    link_add "$1" "$2"
  else
    gw_usage_error link 'Expected a service and a path, or rm and a service.'
  fi
}

complete_link() {
  if (( $# == 0 )); then
    gw_candidate rm 'Unlink a service'
    gw_complete_linked_services
  elif [[ $1 == rm && $# == 1 ]]; then
    gw_complete_linked_services
  elif (( $# == 1 )); then
    print -r -- "$GW_COMPLETE_DIRECTORIES"
  fi
}

link_list() {
  if [[ -z $(gw_config_names "$GW_REPOS") ]]; then
    gw_hint 'No services linked yet. Link one with:' 'gw link <service> <path>'
    return
  fi
  local service repo_path repo branch head
  {
    printf 'SERVICE\tREPO\tBRANCH\tHEAD\n'
    gw_config_entries "$GW_REPOS" | while read -r service repo_path; do
      repo=$(gw_expand_path "$repo_path")
      branch=$(git -C "$repo" branch --show-current 2> /dev/null) || branch='(missing)'
      head=$(git -C "$repo" rev-parse --short=8 HEAD 2> /dev/null) || head='-'
      printf '%s\t%s\t%s\t%s\n' "$service" "$repo_path" "${branch:--}" "$head"
    done
  } | gw_table link_style_cell
}

link_style_cell() {
  case $1 in
    1) REPLY=${C[service]} ;;
    3) REPLY=${C[branch]} ;;
    4) REPLY=${C[commit]} ;;
  esac
}

link_add() {
  local service=$1 repo_path repo
  repo=$(gw_expand_path "$2")
  repo=${repo:a}
  repo_path=$(gw_shorten_path "$repo")
  [[ $service != *[[:space:]@]* && $service != \#* ]] ||
    gw_die "A service name cannot contain spaces or @, or start with #: $service"
  ! gw_is_alias "$service" ||
    gw_die "$service is already a gateway alias, so it cannot be a service name too"
  [[ -d $repo ]] || gw_die "No such directory: $repo_path"
  [[ -f $repo/package.json ]] && grep -q '"deploy"' "$repo/package.json" ||
    gw_die "No package.json with a deploy script in $repo_path"

  gw_config_remove "$GW_REPOS" "$service"
  gw_config_append "$GW_REPOS" "$service $repo_path"
  gw_ok "${E[service]}$service${E[reset]} ${E[muted]}→${E[reset]} $repo_path"
}

link_remove() {
  local service=$1
  gw_config_has "$GW_REPOS" "$service" || gw_die "No link for service: $service"
  gw_config_remove "$GW_REPOS" "$service"
  gw_ok "Unlinked ${E[service]}$service${E[reset]}"
}
