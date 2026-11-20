gw_command health \
  summary 'Show CPU, memory and disk use of a gateway' \
  usage '[gateway]' '' \
  flag '-w --watch' 'Refresh every few seconds until Ctrl+C' \
  note 'Bars turn yellow and then red as CPU, memory or a disk gets close to full.' \
  example 'gw health alpha' \
  example 'gw health alpha --watch'

GW_HEALTH_WATCH_SECONDS=${GW_HEALTH_WATCH_SECONDS:-5}
GW_HEALTH_BAR_WIDTH=10
GW_HEALTH_LOAD_HIGH_PERCENT=70
GW_HEALTH_LOAD_CRITICAL_PERCENT=100
GW_HEALTH_MEMORY_HIGH_PERCENT=70
GW_HEALTH_MEMORY_CRITICAL_PERCENT=85
GW_HEALTH_DISK_HIGH_PERCENT=75
GW_HEALTH_DISK_CRITICAL_PERCENT=90

typeset -gA health_values=()
typeset -ga health_disks=()

cmd_health() {
  gw_parse_arguments health "$@"
  gw_take_gateway health
  (( ${#gw_arguments} == 0 )) || gw_usage_error health "gw health takes only a gateway, not: ${gw_arguments[*]}"
  if gw_has_flag --watch; then
    gw_watch "$GW_HEALTH_WATCH_SECONDS" health_fetch health_print_system
  else
    health_fetch || exit 1
    health_print_system
  fi
}

health_fetch() {
  gw_remote "Reading CPU, memory and disks on $gw_gateway" health || return 1
  health_read "$gw_remote_output"
}

complete_health() {
  gw_complete_gateway_then '' "$@"
}

health_read() {
  local line
  local -a fields
  health_values=()
  health_disks=()
  for line in "${(@f)1}"; do
    [[ -n $line ]] || continue
    fields=("${(@ps:\t:)line}")
    case ${fields[1]} in
      uptime) health_values[uptime]=${fields[2]} ;;
      load) health_values[load]=${fields[2]}; health_values[cpus]=${fields[3]} ;;
      memory) health_values[memory_total]=${fields[2]}; health_values[memory_available]=${fields[3]} ;;
      disk) health_disks+=("${(pj:\t:)fields[2,-1]}") ;;
    esac
  done
}

health_title() {
  print -r -- "${C[bold]}$1${C[reset]}${2:+  ${C[muted]}$2${C[reset]}}"
}

health_color_for() {
  local -i percent=$1 warning=$2 critical=$3
  REPLY=''
  if (( percent >= critical )); then REPLY=${C[bad]}; elif (( percent >= warning )); then REPLY=${C[caution]}; fi
}

health_meter() {
  local label=$1 detail=$3
  local -i percent=$2 warning=$4 critical=$5 filled
  local color empty_cells filled_cells blank=''
  health_color_for $percent $warning $critical
  color=$REPLY
  filled=$(( (percent + 5) / 10 ))
  (( percent == 0 || filled > 0 )) || filled=1
  (( filled <= GW_HEALTH_BAR_WIDTH )) || filled=$GW_HEALTH_BAR_WIDTH
  filled_cells=${(l:filled::█:)blank}
  empty_cells=${(l:GW_HEALTH_BAR_WIDTH - filled::░:)blank}
  print -r -- "  ${(r:9:)label}${color}${filled_cells}${C[reset]}${C[muted]}${empty_cells}${C[reset]}  ${color}${(l:3:)percent}%${C[reset]}  ${C[muted]}$detail${C[reset]}"
}

health_print_system() {
  local REPLY free total_label
  local -a fields
  local -i cpus=${health_values[cpus]:-1} total available
  gw_duration_label "${health_values[uptime]:-0}"
  health_title Resources "up $REPLY"

  local load_now=${${health_values[load]:-0}%% *}
  local -i cpu_percent=$(( load_now * 100 / cpus ))
  health_meter CPU $cpu_percent "load $load_now on $cpus CPUs" \
    $GW_HEALTH_LOAD_HIGH_PERCENT $GW_HEALTH_LOAD_CRITICAL_PERCENT

  total=$(( ${health_values[memory_total]:-0} * 1024 ))
  available=$(( ${health_values[memory_available]:-0} * 1024 ))
  if (( total > 0 )); then
    gw_size_label $available; free=$REPLY
    gw_size_label $total; total_label=$REPLY
    health_meter Memory $(( (total - available) * 100 / total )) "$free free of $total_label" \
      $GW_HEALTH_MEMORY_HIGH_PERCENT $GW_HEALTH_MEMORY_CRITICAL_PERCENT
  fi

  local disk label
  for disk in "${health_disks[@]}"; do
    fields=("${(@ps:\t:)disk}")
    (( fields[2] > 0 )) || continue
    if [[ ${fields[1]} == / ]]; then label=System; else label='SD card'; fi
    gw_size_label $(( (fields[2] - fields[3]) * 1024 ))
    health_meter "$label" $(( fields[3] * 100 / fields[2] )) "$REPLY free" \
      $GW_HEALTH_DISK_HIGH_PERCENT $GW_HEALTH_DISK_CRITICAL_PERCENT
  done
}
