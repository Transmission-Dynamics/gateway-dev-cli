gw_command ssh \
  summary 'Open a shell on a gateway, or run a command there' \
  usage '[gateway] [command...]' '' \
  note 'Everything after the gateway is passed to ssh as the command to run.' \
  example 'gw ssh alpha' \
  example 'gw ssh alpha systemctl status td-transceiver'

cmd_ssh() {
  case ${1:-} in
    -h|--help)
      gw_command_help ssh
      exit 0
      ;;
  esac
  gw_arguments=("$@")
  gw_take_gateway ssh unchecked
  gw_interactive_ssh "$gw_gateway" "${gw_arguments[@]}"
}

complete_ssh() {
  gw_complete_gateway_then '' "$@"
}
