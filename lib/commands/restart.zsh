gw_command restart \
  summary 'Restart services on a gateway' \
  usage '[gateway] <service>...' '' \
  note 'Restarts td-<service>.service for each service, then shows their status.' \
  example 'gw restart alpha rest-api' \
  example 'gw restart transceiver rest-api'

cmd_restart() {
  gw_parse_arguments restart "$@"
  gw_take_gateway restart
  (( ${#gw_arguments} > 0 )) || gw_usage_error restart 'No services given, nothing restarted.'

  local exit_code=0
  local -a services=("${gw_arguments[@]}")
  if gw_remote "Restarting ${(j:, :)services} on $gw_gateway" restart "${services[@]}"; then
    gw_ok "Restarted ${E[service]}${(j:, :)services}${E[reset]}"
  else
    exit_code=1
  fi
  gw_show_status "${services[@]}" || exit 1
  exit $exit_code
}

complete_restart() {
  gw_complete_gateway_then gw_complete_linked_services "$@"
}
