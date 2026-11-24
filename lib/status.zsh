GW_STATUS_HIDDEN_STATES=('not a service' 'disabled' 'off by config')

GW_STATES=(
  'running'        'a long-running service that is up'
  'done'           'a run-once job that ran and finished OK'
  'idle'           'a run-once job not running now (runs on boot, a timer or on demand)'
  'disabled'       'turned off on purpose, not started on boot'
  'off by config'  'its start condition says no, for example it is turned off in td.env'
  'not a service'  'files are deployed, but no td-<name>.service unit runs them'
  'starting'       'being started'
  'stopping'       'being shut down'
  'stopped'        'enabled but not running, should normally be up'
  'crash loop'     'keeps exiting and systemd keeps restarting it'
  'crashed'        'exited with an error, systemd gave up restarting it'
  'not installed'  'neither files nor a unit on the gateway (only for services asked for by name)'
)

typeset -g gw_status_today=''
typeset -gi gw_status_hidden=0 gw_status_hide_inactive=0
typeset -g gw_status_output=''
typeset -ga gw_status_columns=()

gw_state_color() {
  case $1 in
    running|done) REPLY=${C[good]} ;;
    crashed|'crash loop'|'not installed') REPLY=${C[bad]} ;;
    idle|disabled|'off by config'|'not a service') REPLY=${C[muted]} ;;
    *) REPLY=${C[caution]} ;;
  esac
}

gw_style_status_cell() {
  local column=$1 cell=$2
  case ${gw_status_columns[column]} in
    SERVICE) REPLY=${C[service]} ;;
    COMMIT) REPLY=${C[commit]} ;;
    'DEPLOYED (UTC)') if [[ $cell == $gw_status_today* ]]; then REPLY=${C[bold]}${C[green]}; else REPLY=${C[muted]}; fi ;;
    'DEPLOYED BY') REPLY=${C[person]} ;;
    STATE) gw_state_color "$cell" ;;
    STARTED) REPLY=${C[muted]} ;;
  esac
}

gw_started_label() {
  if [[ $1 != <-> ]]; then
    REPLY=-
    return
  fi
  gw_duration_label "$1"
  REPLY="$REPLY ago"
}

gw_show_status() {
  gw_read_status "$@" || return 1
  gw_print_status
}

gw_read_status() {
  gw_status_hide_inactive=0
  if [[ ${1:-} == --hide-inactive ]]; then
    gw_status_hide_inactive=1
    shift
  fi
  gw_remote "Reading services on $gw_gateway" status "$@" || return 1
  gw_status_output=$gw_remote_output
}

gw_print_status() {
  local -i with_person=0
  local line REPLY
  local -a rows fields
  gw_status_hidden=0
  if [[ -z $gw_status_output ]]; then
    gw_note "Nothing is deployed on $gw_gateway"
    return 0
  fi
  for line in "${(@f)gw_status_output}"; do
    [[ -n $line ]] || continue
    fields=("${(@ps:\t:)line}")
    if (( gw_status_hide_inactive && ${GW_STATUS_HIDDEN_STATES[(Ie)${fields[5]}]} )); then
      gw_status_hidden+=1
      continue
    fi
    [[ ${fields[4]} == - ]] || with_person=1
    rows+=("$line")
  done
  (( ${#rows} > 0 )) || return 0
  gw_status_columns=(SERVICE COMMIT 'DEPLOYED (UTC)')
  (( ! with_person )) || gw_status_columns+=('DEPLOYED BY')
  gw_status_columns+=(STATE STARTED)
  gw_status_today=$(date -u '+%Y-%m-%d')
  {
    print -r -- "${(pj:\t:)gw_status_columns}"
    for line in "${rows[@]}"; do
      fields=("${(@ps:\t:)line}")
      gw_started_label "${fields[6]}"
      if (( with_person )); then
        printf '%s\t%s\t%s\t%s\t%s\t%s\n' "${fields[1,5][@]}" "$REPLY"
      else
        printf '%s\t%s\t%s\t%s\t%s\n' "${fields[1,3][@]}" "${fields[5]}" "$REPLY"
      fi
    done
  } | gw_table gw_style_status_cell
}

gw_print_state_legend() {
  local width=0 blank='' padding index REPLY
  for (( index = 1; index <= ${#GW_STATES}; index += 2 )); do
    if (( ${#GW_STATES[index]} > width )); then width=${#GW_STATES[index]}; fi
  done
  print
  print -r -- "${C[title]}STATES${C[reset]}"
  for (( index = 1; index <= ${#GW_STATES}; index += 2 )); do
    gw_state_color "${GW_STATES[index]}"
    padding=$(( width - ${#GW_STATES[index]} + 2 ))
    print -r -- "${REPLY}${GW_STATES[index]}${C[reset]}${(l:padding:)blank}${C[muted]}${GW_STATES[index + 1]}${C[reset]}"
  done
}
