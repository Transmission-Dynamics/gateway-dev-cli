gw_command devices \
  summary 'List devices advertising to a gateway that it can connect to' \
  usage '[gateway] [uuid...]' '' \
  flag '-s --since <time>' 'Only devices seen within this time, like 30s, 10m, 2h or 1d (default 2h)' \
  flag '-t --type <type>' 'Only devices of this type, like SBR or MT-V2' \
  flag '-w --watch' 'Refresh every few seconds until Ctrl+C' \
  flag '-v --verbose' 'Also show the temperature each device reports' \
  note 'Lists the connectable adverts the transceiver recorded, newest first. Non-connectable' \
  note 'adverts are left out, because the gateway cannot connect to a device while it sends them.' \
  note 'A device in a low-power mode, such as MTv2 pressure, is connectable only now and then,' \
  note 'so it can look minutes old while it is active.' \
  note 'TASKS lists the commands waiting for the device; they run the next time it connects.' \
  example 'gw devices alpha' \
  example 'gw devices alpha --since 10m --type SBR' \
  example 'gw devices alpha b2b2b2b2b2b2 --watch'

GW_DEVICES_DEFAULT_SINCE=2h
GW_DEVICES_WATCH_SECONDS=3
GW_DEVICES_RSSI_WEAK=-75
GW_DEVICES_RSSI_UNUSABLE=-85
GW_DEVICES_FRESH_SECONDS=60
GW_DEVICES_RECENT_SECONDS=600

typeset -g devices_type='' devices_since='' devices_since_seconds=0
typeset -ga devices_columns=()
typeset -gA devices_seen_seconds=()
typeset -g devices_rows=''

cmd_devices() {
  gw_parse_arguments devices "$@"
  gw_flag_value --since "$GW_DEVICES_DEFAULT_SINCE"
  devices_since=$REPLY
  gw_parse_duration "$devices_since" ||
    gw_usage_error devices "Not a time like 30s, 10m, 2h or 1d: $devices_since"
  devices_since_seconds=$REPLY
  gw_flag_value --type ''
  devices_type=$REPLY
  gw_take_gateway devices

  if gw_has_flag --watch; then
    gw_watch "$GW_DEVICES_WATCH_SECONDS" devices_fetch_rows devices_show_rows
  else
    devices_fetch || exit 1
    devices_print "$REPLY"
  fi
}

complete_devices() {
  gw_complete_gateway_then '' "$@"
}

devices_fetch() {
  local uuid line
  local -a rows=() fields
  gw_remote "Reading devices on $gw_gateway" devices "$devices_since_seconds" || return 1
  for line in "${(@f)gw_remote_output}"; do
    [[ -n $line ]] || continue
    fields=("${(@ps:\t:)line}")
    if [[ -n $devices_type && ${(L)fields[2]} != ${(L)devices_type} ]]; then continue; fi
    if (( ${#gw_arguments} > 0 && ! ${gw_arguments[(Ie)${fields[1]}]} )); then continue; fi
    rows+=("$line")
  done
  REPLY=${(F)rows}
}

devices_print() {
  local rows=$1 line count
  local -a fields
  if [[ -z $rows ]]; then
    gw_note "No connectable device seen on $gw_gateway in the last $devices_since$(devices_filter_label)"
    return
  fi
  local -a lines=("${(@f)rows}")
  count=${#lines}
  devices_columns=(UUID TYPE RSSI AGO BATTERY)
  if gw_has_flag --verbose; then devices_columns+=(TEMP); fi
  devices_columns+=(TASKS)
  devices_seen_seconds=()
  local -a table=("${(pj:\t:)devices_columns}")
  local row
  for line in "${lines[@]}"; do
    fields=("${(@ps:\t:)line}")
    devices_ago_cell "${fields[1]}" "${fields[5]}"
    row="${fields[1]}"$'\t'"${fields[2]:--}"$'\t'"${fields[3]:--}"$'\t'"$REPLY"
    row+=$'\t'"$(devices_measurement "${fields[6]:-}" '%.2f V')"
    if gw_has_flag --verbose; then row+=$'\t'"$(devices_measurement "${fields[7]:-}" '%.1f °C')"; fi
    table+=("$row"$'\t'"${fields[8]:--}")
  done
  print -rl -- "${table[@]}" | gw_table devices_style_cell
  print
  print -r -- "${C[muted]}$count $(devices_plural "$count") seen in the last $devices_since$(devices_filter_label)${C[reset]}"
  if [[ ${lines[1]} == *$'\t?' ]]; then
    gw_warn "Could not read the pending tasks on $gw_gateway, TASKS shows ?"
  fi
}

devices_fetch_rows() {
  devices_fetch || return 1
  devices_rows=$REPLY
}

devices_show_rows() {
  devices_print "$devices_rows"
}

devices_filter_label() {
  local -a parts=()
  [[ -z $devices_type ]] || parts+=("type $devices_type")
  (( ${#gw_arguments} == 0 )) || parts+=("${(j:, :)gw_arguments}")
  (( ${#parts} == 0 )) || print -r -- " (${(j:, :)parts})"
}

devices_plural() {
  if (( $1 == 1 )); then print -r -- device; else print -r -- devices; fi
}

devices_ago_cell() {
  local uuid=$1 seconds=$2
  REPLY=-
  [[ $seconds == <-> ]] || return 0
  devices_seen_seconds[$uuid]=$seconds
  gw_duration_label "$seconds"
}

devices_measurement() {
  local value=$1 format=$2
  if [[ -z $value || $value == 0 || $value == 0.0 ]]; then
    print -r -- -
  else
    printf "$format\n" "$value"
  fi
}

devices_style_cell() {
  local column=$1 cell=$2
  case ${devices_columns[column]} in
    UUID) REPLY=${C[service]} ;;
    TYPE) REPLY=${C[branch]} ;;
    RSSI)
      if (( cell < GW_DEVICES_RSSI_UNUSABLE )); then REPLY=${C[bad]}
      elif (( cell < GW_DEVICES_RSSI_WEAK )); then REPLY=${C[caution]}
      fi
      ;;
    AGO)
      local -i seconds=${devices_seen_seconds[$3]:-0}
      if (( seconds < GW_DEVICES_FRESH_SECONDS )); then REPLY=${C[good]}
      elif (( seconds < GW_DEVICES_RECENT_SECONDS )); then REPLY=${C[caution]}
      else REPLY=${C[muted]}
      fi
      ;;
    TASKS) REPLY=${C[caution]} ;;
  esac
}
