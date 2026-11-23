GW_TAGLINE='work with TD gateways from your Mac'

GW_HELP_GROUPS=(
  'Session' 'session'
  'Inspect' 'status health devices submodules logs'
  'Operate' 'deploy restart ssh'
  'Set up' 'alias link target use doctor'
)

typeset -ga GW_COMMANDS=()
typeset -gA GW_SUMMARY=() GW_USAGE=() GW_FLAGS=() GW_NOTES=() GW_EXAMPLES=() GW_COMMAND_ALIASES=()
typeset -ga gw_arguments=() gw_flags=()
typeset -gA gw_flag_values=()
typeset -gA H=()
typeset -g gw_help_fd=1

gw_command() {
  local command=$1
  shift
  GW_COMMANDS+=("$command")
  GW_SUMMARY[$command]=''
  GW_USAGE[$command]=''
  GW_FLAGS[$command]=''
  GW_NOTES[$command]=''
  GW_EXAMPLES[$command]=''
  while (( $# > 0 )); do
    case $1 in
      summary) GW_SUMMARY[$command]=$2; shift 2 ;;
      usage) GW_USAGE[$command]+=${GW_USAGE[$command]:+$'\n'}$2$'\t'$3; shift 3 ;;
      flag) GW_FLAGS[$command]+=${GW_FLAGS[$command]:+$'\n'}$2$'\t'$3; shift 3 ;;
      note) GW_NOTES[$command]+=${GW_NOTES[$command]:+$'\n'}$2; shift 2 ;;
      example) GW_EXAMPLES[$command]+=${GW_EXAMPLES[$command]:+$'\n'}$2; shift 2 ;;
      alias) GW_COMMAND_ALIASES[$2]=$command; shift 2 ;;
      *) gw_die "gw_command $command: unknown key $1" ;;
    esac
  done
}

gw_is_command() {
  (( ${GW_COMMANDS[(Ie)$1]} ))
}

gw_main() {
  local command=${1:-}
  case $command in
    ''|-h|--help)
      gw_help
      exit 0
      ;;
    help)
      if [[ -n ${2:-} ]]; then
        gw_require_command "${GW_COMMAND_ALIASES[$2]:-$2}"
        gw_command_help "${GW_COMMAND_ALIASES[$2]:-$2}"
      else
        gw_help
      fi
      exit 0
      ;;
    -V|--version|version)
      gw_version
      exit 0
      ;;
    __complete)
      shift
      gw_complete "$@"
      exit 0
      ;;
  esac
  shift

  command=${GW_COMMAND_ALIASES[$command]:-$command}
  gw_require_command "$command"
  if [[ $command == session ]]; then gw_help_fd=2; fi
  "cmd_$command" "$@"
}

gw_require_command() {
  local command=$1
  ! gw_is_command "$command" || return 0
  gw_error "Unknown command: $command"
  gw_closest_or_prefix "$command" "${GW_COMMANDS[@]}"
  [[ -z $REPLY ]] || gw_hint 'Did you mean:' "gw $REPLY"
  gw_hint 'All commands:' 'gw --help'
  exit 2
}

gw_version() {
  local version
  version=$(git -C "$GW_ROOT" describe --tags --always --dirty 2> /dev/null) || version=unknown
  print -r -- "gw $version"
}

gw_parse_arguments() {
  local command=$1 argument
  shift
  gw_arguments=()
  gw_flags=()
  gw_flag_values=()
  while (( $# > 0 )); do
    argument=$1
    shift
    case $argument in
      --)
        gw_arguments+=("$@")
        break
        ;;
      -h|--help)
        gw_command_help "$command"
        exit 0
        ;;
      -[[:alpha:]][[:alpha:]]*)
        set -- ${${(s::)argument[2,-1]}/#/-} "$@"
        ;;
      --*=*)
        gw_take_flag "$command" "${argument%%=*}" "${argument#*=}" given
        ;;
      -?*)
        gw_take_flag "$command" "$argument" "${1:-}" next
        if gw_flag_needs_value "$command" "$REPLY"; then
          shift
        fi
        ;;
      *)
        gw_arguments+=("$argument")
        ;;
    esac
  done
}

gw_take_flag() {
  local command=$1 flag=$2 value=$3 source=$4 canonical
  gw_canonical_flag "$command" "$flag"
  canonical=$REPLY
  gw_flags+=("$canonical")
  if ! gw_flag_needs_value "$command" "$canonical"; then
    [[ $source != given ]] || gw_usage_error "$command" "$canonical takes no value"
    REPLY=$canonical
    return
  fi
  if [[ $source == next && ( -z $value || $value == -* ) ]]; then
    gw_usage_error "$command" "$canonical needs a value: $canonical $(gw_flag_placeholder "$command" "$canonical")"
  fi
  gw_flag_values[$canonical]=$value
  REPLY=$canonical
}

gw_has_flag() {
  (( ${gw_flags[(Ie)$1]} ))
}

gw_flag_value() {
  REPLY=${gw_flag_values[$1]:-$2}
}

gw_flag_spec_names() {
  print -r -- ${(M)${=1}:#-*}
}

gw_flag_spec_placeholder() {
  print -r -- ${(M)${=1}:#<*}
}

gw_flag_spec() {
  local command=$1 flag=$2 line
  local -a names
  for line in "${(@f)GW_FLAGS[$command]}"; do
    names=($(gw_flag_spec_names "${line%%$'\t'*}"))
    if (( ${names[(Ie)$flag]} )); then
      REPLY=${line%%$'\t'*}
      return 0
    fi
  done
  return 1
}

gw_flag_needs_value() {
  gw_flag_spec "$1" "$2" && [[ -n $(gw_flag_spec_placeholder "$REPLY") ]]
}

gw_flag_placeholder() {
  gw_flag_spec "$1" "$2"
  gw_flag_spec_placeholder "$REPLY"
}

gw_flag_names() {
  local command=$1 line
  for line in "${(@f)GW_FLAGS[$command]}"; do
    [[ -z $line ]] || gw_flag_spec_names "${line%%$'\t'*}"
  done
}

gw_canonical_flag() {
  local command=$1 flag=$2 line
  local -a names
  for line in "${(@f)GW_FLAGS[$command]}"; do
    names=($(gw_flag_spec_names "${line%%$'\t'*}"))
    if (( ${names[(Ie)$flag]} )); then
      REPLY=${names[-1]}
      return
    fi
  done
  names=(${=$(gw_flag_names "$command")})
  gw_closest_or_prefix "$flag" "${names[@]}"
  gw_usage_error "$command" "Unknown option for gw $command: $flag${REPLY:+ (did you mean $REPLY?)}"
}

gw_usage_error() {
  local command=$1
  shift
  gw_error "$@"
  gw_help_fd=2
  gw_help_palette
  gw_help_usage_forms "$command"
  gw_hint 'Details:' "gw $command --help"
  exit 2
}

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

gw_edit_distance() {
  local a=$1 b=$2 i j cost best
  local -a previous current
  for (( j = 0; j <= ${#b}; j++ )); do
    previous[j+1]=$j
  done
  for (( i = 1; i <= ${#a}; i++ )); do
    current=($i)
    for (( j = 1; j <= ${#b}; j++ )); do
      if [[ ${a[i]} == "${b[j]}" ]]; then cost=0; else cost=1; fi
      best=$(( previous[j] + cost ))
      if (( previous[j + 1] + 1 < best )); then best=$(( previous[j + 1] + 1 )); fi
      if (( current[j] + 1 < best )); then best=$(( current[j] + 1 )); fi
      current[j+1]=$best
    done
    previous=("${current[@]}")
  done
  REPLY=${previous[${#b} + 1]}
}

gw_closest() {
  local word=$1 candidate closest='' closest_distance=99 limit=1
  shift
  if (( ${#word} >= 5 )); then limit=2; fi
  for candidate in "$@"; do
    [[ -n $candidate ]] || continue
    gw_edit_distance "$word" "$candidate"
    if (( REPLY <= limit && REPLY < closest_distance )); then
      closest=$candidate
      closest_distance=$REPLY
    fi
  done
  REPLY=$closest
}

gw_closest_or_prefix() {
  local word=$1 candidate
  shift
  gw_closest "$word" "$@"
  [[ -z $REPLY ]] || return 0
  (( ${#word} >= 3 )) || return 0
  for candidate in "$@"; do
    if [[ $candidate == "$word"* ]]; then
      REPLY=$candidate
      return 0
    fi
  done
}

gw_parse_duration() {
  local duration=$1
  [[ $duration =~ '^([0-9]+)([smhd]?)$' ]] || return 1
  local -A unit_seconds=(s 1 m 60 h 3600 d 86400 '' 1)
  REPLY=$(( match[1] * unit_seconds[${match[2]}] ))
  (( REPLY > 0 ))
}
