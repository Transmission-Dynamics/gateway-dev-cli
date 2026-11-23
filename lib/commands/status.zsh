gw_command status \
  summary 'Show what is deployed on a gateway and whether it runs' \
  usage '[gateway] [service...]' '' \
  flag '-a --all' 'Also list disabled services, folders no unit runs, and td-* units with nothing deployed' \
  flag '-v --verbose' 'Explain the states below the table' \
  flag '-w --watch' 'Refresh every few seconds until Ctrl+C' \
  note 'Without services, lists what is deployed, most recent deploy first. Disabled services and' \
  note 'folders that no unit runs are hidden unless you add --all or name them.' \
  note 'DEPLOYED BY is filled in for deploys made with gw deploy.' \
  example 'gw status alpha' \
  example 'gw status alpha --all --verbose' \
  example 'gw status alpha --watch' \
  example 'gw status transceiver rest-api'

GW_STATUS_WATCH_SECONDS=5

typeset -ga status_options=()

cmd_status() {
  gw_parse_arguments status "$@"
  gw_take_gateway status
  status_options=()
  if gw_has_flag --all; then
    status_options+=(--all)
  elif (( ${#gw_arguments} == 0 )); then
    status_options+=(--hide-inactive)
  fi
  if gw_has_flag --watch; then
    gw_watch "$GW_STATUS_WATCH_SECONDS" status_read status_show
  else
    status_read || exit 1
    status_show
  fi
}

status_read() {
  gw_read_status "${status_options[@]}" "${gw_arguments[@]}"
}

status_show() {
  gw_print_status
  if (( gw_status_hidden > 0 )); then
    gw_hint "$gw_status_hidden turned off or not a service, hidden. Show them with:" "gw status${gw_gateway_word:+ $gw_gateway_word} --all"
  fi
  if gw_has_flag --verbose; then gw_print_state_legend; fi
}

complete_status() {
  gw_complete_gateway_then gw_complete_linked_services "$@"
}
