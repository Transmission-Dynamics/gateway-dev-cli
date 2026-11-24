GW_TAGLINE='work with TD gateways from your Mac'

GW_HELP_GROUPS=(
  'Session' 'session'
  'Inspect' 'status health devices submodules logs'
  'Operate' 'deploy restart ssh'
  'Set up' 'alias link target use doctor update'
)

typeset -gA H=()
typeset -g gw_help_fd=1

gw_help_palette() {
  if (( gw_help_fd == 2 )); then
    H=("${(@kv)E}")
  else
    H=("${(@kv)C}")
  fi
}

gw_help_line() {
  print -u$gw_help_fd -r -- "$*"
}

gw_help_title() {
  gw_help_line "${H[title]}$1${H[reset]}"
}

gw_help() {
  local title names command width=0
  local -a grouped=()
  gw_help_palette
  for command in "${GW_COMMANDS[@]}"; do
    if (( ${#command} > width )); then width=${#command}; fi
  done

  gw_help_line "${H[bold]}gw${H[reset]} – $GW_TAGLINE"
  gw_help_line
  gw_help_title Usage
  gw_help_line "  ${H[muted]}gw${H[reset]} ${H[service]}<command>${H[reset]} ${H[argument]}[gateway] [arguments]${H[reset]}"
  for title names in "${GW_HELP_GROUPS[@]}"; do
    gw_help_line
    gw_help_title "$title"
    for command in ${=names}; do
      gw_is_command "$command" || continue
      grouped+=("$command")
      gw_help_command_row "$command" "$width"
    done
  done
  if (( ${#grouped} < ${#GW_COMMANDS} )); then
    gw_help_line
    gw_help_title Other
    for command in "${GW_COMMANDS[@]}"; do
      (( ${grouped[(Ie)$command]} )) || gw_help_command_row "$command" "$width"
    done
  fi
  gw_help_line
  gw_help_title Gateway
  gw_help_line '  A saved alias such as alpha, or an ssh address such as td@alpha.local.'
  gw_help_line '  Leave it out while a session is active.'
  gw_help_line
  gw_help_line "${H[muted]}Run${H[reset]} ${H[command]}gw <command> --help${H[reset]} ${H[muted]}for options and examples.${H[reset]}"
}

gw_help_command_row() {
  local command=$1 width=$2
  gw_help_line "  ${H[service]}${(r:width:)command}${H[reset]}  ${GW_SUMMARY[$command]}"
}

gw_help_usage_forms() {
  local command=$1 line form description width=0 blank='' padding
  local -a lines=("${(@f)GW_USAGE[$command]}")
  for line in "${lines[@]}"; do
    form=${line%%$'\t'*}
    if (( ${#form} > width )); then width=${#form}; fi
  done
  for line in "${lines[@]}"; do
    form=${line%%$'\t'*}
    description=${line#*$'\t'}
    padding=$(( width - ${#form} + 3 ))
    gw_help_line "  ${H[muted]}gw${H[reset]} ${H[service]}$command${H[reset]} ${H[argument]}$form${H[reset]}${description:+${(l:padding:)blank}${H[muted]}$description${H[reset]}}"
  done
}

gw_help_flags() {
  local command=$1 line width=0 blank='' padding
  local -a lines=("${(@f)GW_FLAGS[$command]}")
  lines=(${lines:#})
  lines+=("-h --help"$'\t'"Show this help")
  for line in "${lines[@]}"; do
    gw_help_flag_label "${line%%$'\t'*}"
    if (( ${#REPLY} > width )); then width=${#REPLY}; fi
  done
  gw_help_line
  gw_help_title Options
  for line in "${lines[@]}"; do
    gw_help_flag_label "${line%%$'\t'*}"
    padding=$(( width - ${#REPLY} + 3 ))
    gw_help_line "  ${H[argument]}$REPLY${H[reset]}${(l:padding:)blank}${line#*$'\t'}"
  done
}

gw_help_flag_label() {
  local spec=$1 placeholder
  local -a names=($(gw_flag_spec_names "$spec"))
  placeholder=$(gw_flag_spec_placeholder "$spec")
  REPLY=${(j:, :)names}${placeholder:+ $placeholder}
}

gw_command_help() {
  local command=$1 line
  gw_help_palette
  gw_help_line "${GW_SUMMARY[$command]}"
  gw_help_line
  gw_help_title Usage
  gw_help_usage_forms "$command"
  gw_help_flags "$command"
  if [[ -n ${GW_NOTES[$command]} ]]; then
    gw_help_line
    for line in "${(@f)GW_NOTES[$command]}"; do
      gw_help_line "$line"
    done
  fi
  if [[ -n ${GW_EXAMPLES[$command]} ]]; then
    gw_help_line
    gw_help_title Examples
    for line in "${(@f)GW_EXAMPLES[$command]}"; do
      gw_help_line "  ${H[muted]}\$${H[reset]} $line"
    done
  fi
}
