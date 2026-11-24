typeset -ga GW_COMMANDS=()
typeset -gA GW_SUMMARY=() GW_USAGE=() GW_FLAGS=() GW_NOTES=() GW_EXAMPLES=() GW_COMMAND_ALIASES=()
typeset -ga gw_arguments=() gw_flags=()
typeset -gA gw_flag_values=()

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
  if [[ -f $GW_ROOT/VERSION ]]; then
    version=$(< "$GW_ROOT/VERSION")
  else
    version=$(git -C "$GW_ROOT" describe --tags --always --dirty 2> /dev/null) || version=unknown
  fi
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
