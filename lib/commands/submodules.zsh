gw_command submodules \
  summary 'Show the submodule versions deployed services were built with' \
  usage '[gateway] [service...]' '' \
  note 'Reads manifest.json of each service, so only services built with a manifest are listed.' \
  note 'Each version is coloured against the newest one of that submodule on the gateway.' \
  example 'gw submodules alpha' \
  example 'gw submodules transceiver rest-api frontend'

GW_UNKNOWN_VERSION=0.0.0

autoload -Uz is-at-least

typeset -ga submodules_columns=()
typeset -gA submodules_newest=()

cmd_submodules() {
  gw_parse_arguments submodules "$@"
  gw_take_gateway submodules
  gw_remote "Reading manifests on $gw_gateway" submodules "${gw_arguments[@]}" || exit 1
  if [[ -z $gw_remote_output ]]; then
    gw_note "No service on $gw_gateway has a manifest.json"
    return
  fi
  submodules_print_grid "$gw_remote_output"
}

complete_submodules() {
  gw_complete_gateway_then gw_complete_linked_services "$@"
}

submodules_version_number() {
  local version=${1#v}
  print -r -- "${version%%-*}"
}

submodules_sorted_by_count() {
  local name
  local -A counts=("$@")
  for name in ${(k)counts}; do
    printf '%d\t%s\n' "${counts[$name]}" "$name"
  done | sort -t $'\t' -k1,1nr -k2,2 | cut -f2
}

submodules_print_grid() {
  local rows=$1 service service_version submodule submodule_version number newest
  local -a services=()
  local -A service_versions=() cells=() uses=() counts=()

  while IFS=$'\t' read -r service service_version submodule submodule_version; do
    if (( ! ${+service_versions[$service]} )); then
      service_versions[$service]=$service_version
      counts[$service]=0
    fi
    [[ $submodule != - ]] || continue
    cells[$service/$submodule]=$submodule_version
    uses[$submodule]=$(( ${uses[$submodule]:-0} + 1 ))
    counts[$service]=$(( counts[$service] + 1 ))
  done <<< "$rows"

  services=("${(@f)$(submodules_sorted_by_count "${(@kv)counts}")}")
  submodules_columns=(${(f)"$(submodules_sorted_by_count "${(@kv)uses}")"})

  submodules_newest=()
  for submodule in "${submodules_columns[@]}"; do
    newest=''
    for service in "${services[@]}"; do
      (( ${+cells[$service/$submodule]} )) || continue
      number=$(submodules_version_number "${cells[$service/$submodule]}")
      [[ $number != $GW_UNKNOWN_VERSION ]] || continue
      if [[ -z $newest ]] || is-at-least "$newest" "$number"; then newest=$number; fi
    done
    submodules_newest[$submodule]=$newest
  done

  {
    printf 'SERVICE\tVERSION'
    (( ${#submodules_columns} == 0 )) || printf '\t%s' "${submodules_columns[@]}"
    print
    for service in "${services[@]}"; do
      printf '%s\t%s' "$service" "${service_versions[$service]}"
      for submodule in "${submodules_columns[@]}"; do
        printf '\t%s' "${cells[$service/$submodule]:--}"
      done
      print
    done
  } | gw_table submodules_style_cell

  print
  print -r -- "${C[good]}newest${C[reset]}  ${C[caution]}behind${C[reset]}  ${C[bad]}major version behind${C[reset]}  ${C[muted]}unknown${C[reset]}"
}

submodules_style_cell() {
  local column=$1 cell=$2 submodule number newest color suffix=''
  case $column in
    1) REPLY=${C[bold]}; return ;;
    2) return ;;
  esac
  submodule=${submodules_columns[column - 2]}
  number=$(submodules_version_number "$cell")
  newest=${submodules_newest[$submodule]}
  if [[ $number == $GW_UNKNOWN_VERSION ]]; then
    color=${C[muted]}
  elif [[ $number == "$newest" ]]; then
    color=${C[good]}
  elif [[ ${number%%.*} != "${newest%%.*}" ]]; then
    color=${C[bad]}
  else
    color=${C[caution]}
  fi
  if [[ $cell == *-* ]]; then suffix=-${cell#*-}; fi
  gw_styled_cell="${color}${cell%%-*}${C[reset]}${C[muted]}${suffix}${C[reset]}"
}
