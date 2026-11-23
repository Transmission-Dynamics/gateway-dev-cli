gw_command logs \
  summary 'Follow the logs of services on a gateway' \
  usage '[gateway] [service...]' 'Without a service, follows the transceiver' \
  flag '-s --since <time>' 'Start from this long ago, like 30s, 10m, 2h or 1d' \
  flag '-n --lines <count>' 'How many earlier lines to show first (default 50)' \
  flag '-N --no-follow' 'Print the lines and exit instead of following' \
  note 'Several services are merged into one stream, ordered by time. Press Ctrl+C to stop.' \
  example 'gw logs alpha' \
  example 'gw logs alpha voltage-monitor --since 10m' \
  example 'gw logs alpha rest-api transceiver -n 200 --no-follow'

GW_LOGS_SCRIPT=/usr/jrd/scripts/show_logs.sh
GW_LOGS_DEFAULT_SERVICE=transceiver
GW_LOGS_DEFAULT_LINES=50

cmd_logs() {
  gw_parse_arguments logs "$@"
  local -a journal_options=() services=()
  if gw_has_flag --since; then
    gw_flag_value --since ''
    gw_parse_duration "$REPLY" || gw_usage_error logs "Not a time like 30s, 10m, 2h or 1d: $REPLY"
    journal_options+=("--since=-${REPLY}s")
  else
    gw_flag_value --lines "$GW_LOGS_DEFAULT_LINES"
    [[ $REPLY == <1-> ]] || gw_usage_error logs "Not a number of lines: $REPLY"
    journal_options+=(-n "$REPLY")
  fi
  gw_has_flag --no-follow || journal_options+=(-f)
  gw_take_gateway logs
  services=("${gw_arguments[@]}")
  (( ${#services} > 0 )) || services=("$GW_LOGS_DEFAULT_SERVICE")
  logs_check_services "${services[@]}"
  local service
  for service in "${services[@]}"; do journal_options=(-u "td-$service.service" "${journal_options[@]}"); done
  gw_interactive_ssh -t "$gw_gateway" "$GW_LOGS_SCRIPT" "${(@q)journal_options}"
}

logs_check_services() {
  local service line missing=0
  local -a known=() quiet=() fields
  local journal_age=''
  gw_remote "Checking services on $gw_gateway" logs "$@" || exit 1
  for line in "${(@f)gw_remote_output}"; do
    fields=("${(@ps:\t:)line}")
    case ${fields[1]} in
      unit) known+=("${fields[2]}") ;;
      quiet) quiet+=("${fields[2]}") ;;
      journal_age) journal_age=${fields[2]} ;;
    esac
  done
  for service in "$@"; do
    (( ${known[(Ie)$service]} )) && continue
    missing=1
    gw_error "No service $service on $gw_gateway"
    gw_closest "$service" "${known[@]}"
    [[ -z $REPLY ]] || gw_hint 'Did you mean:' "gw logs${gw_gateway_word:+ $gw_gateway_word} $REPLY"
  done
  (( ! missing )) || exit 1
  logs_warn_quiet "$journal_age" "${quiet[@]}"
}

logs_warn_quiet() {
  local journal_age=$1 window='the journal'
  shift
  (( $# > 0 )) || return 0
  if [[ $journal_age == <-> ]]; then
    gw_duration_label "$journal_age"
    window="the last $REPLY, all the journal keeps"
  fi
  gw_warn "${(j:, :)@} wrote nothing in $window"
  gw_has_flag --no-follow || gw_hint 'Waiting for new lines; stop with' Ctrl+C
}

complete_logs() {
  gw_complete_gateway_then gw_complete_linked_services "$@"
}
