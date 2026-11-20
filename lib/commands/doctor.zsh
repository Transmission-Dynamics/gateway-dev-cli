gw_command doctor \
  summary 'Check that gw is set up correctly on this Mac' \
  usage '' '' \
  note 'Checks the install, the tools gw needs, every linked repo and target file, and that each' \
  note 'saved gateway accepts your ssh key. Changes nothing. Every problem comes with the fix.' \
  example 'gw doctor'

GW_DOCTOR_SSH_TIMEOUT=5
GW_DOCTOR_TOOLS=(git npm ssh)

typeset -gi doctor_problems=0 doctor_warnings=0

cmd_doctor() {
  gw_parse_arguments doctor "$@"
  (( ${#gw_arguments} == 0 )) || gw_usage_error doctor "gw doctor takes no arguments, not: ${gw_arguments[*]}"
  doctor_check_install
  doctor_check_repos
  doctor_check_targets
  doctor_check_gateways
  doctor_summary
}

doctor_problem() {
  doctor_problems+=1
  gw_error "$1"
  [[ -z ${2:-} ]] || gw_hint "  $2" "${3:-}"
}

doctor_warning() {
  doctor_warnings+=1
  gw_warn "$1"
  [[ -z ${2:-} ]] || gw_hint "  $2" "${3:-}"
}

doctor_check_install() {
  local command_path zshrc=${ZDOTDIR:-$HOME}/.zshrc tool
  local -a missing=()
  gw_heading 'Install'
  command_path=$(whence -p gw 2> /dev/null || true)
  if [[ -z $command_path ]]; then
    doctor_problem 'gw is not on your PATH' 'Fix:' "$(gw_shorten_path "$GW_ROOT")/install.sh"
  elif [[ ${command_path:A} != ${GW_ROOT:A}/bin/gw ]]; then
    doctor_problem "gw on your PATH is $(gw_shorten_path "${command_path:A}"), not this clone" 'Fix:' "$(gw_shorten_path "$GW_ROOT")/install.sh"
  else
    gw_ok "gw on your PATH runs $(gw_shorten_path "$GW_ROOT")"
  fi

  if [[ -f $zshrc ]] && grep -qF "source ${(q)GW_ROOT}/shell/gw.zsh" "$zshrc"; then
    gw_ok "$(gw_shorten_path "$zshrc") loads the shell integration (sessions, prompt, tab completion)"
  elif [[ -f $zshrc ]] && grep -qxF "$GW_ZSHRC_BLOCK_START" "$zshrc"; then
    doctor_problem "$(gw_shorten_path "$zshrc") loads gw from another folder" 'Fix:' "$(gw_shorten_path "$GW_ROOT")/install.sh"
  else
    doctor_problem "$(gw_shorten_path "$zshrc") does not load the shell integration, so gw session cannot work" \
      'Fix:' "$(gw_shorten_path "$GW_ROOT")/install.sh"
  fi

  for tool in "${GW_DOCTOR_TOOLS[@]}"; do
    whence -p "$tool" > /dev/null || missing+=("$tool")
  done
  if (( ${#missing} == 0 )); then
    gw_ok "${(j:, :)GW_DOCTOR_TOOLS} are installed"
  else
    doctor_problem "Not installed: ${(j:, :)missing}" 'Install them, for example with:' "brew install ${missing[*]}"
  fi
}

doctor_check_repos() {
  local service repo_path repo
  local -a target_files
  print -u2
  gw_heading 'Linked repos'
  if [[ -z $(gw_config_entries "$GW_REPOS") ]]; then
    doctor_warning 'No repo is linked, so gw deploy has nothing to build' 'Link one with:' 'gw link <service> <path>'
    return
  fi
  gw_config_entries "$GW_REPOS" | while read -r service repo_path; do
    repo=$(gw_expand_path "$repo_path")
    if [[ ! -d $repo ]]; then
      doctor_problem "$service: $repo_path does not exist" 'Fix:' "gw link $service <path to the repo>"
    elif ! git -C "$repo" rev-parse --git-dir > /dev/null 2>&1; then
      doctor_problem "$service: $repo_path is not a git repo" 'Fix:' "gw link $service <path to the repo>"
    else
      target_files=("${(@f)$(gw_repo_target_files "$repo")}")
      if [[ -z ${target_files[1]:-} ]]; then
        doctor_problem "$service: no target file inside $repo_path, so gw deploy cannot point it at a gateway" \
          'Fix:' "gw target add $service <file its deploy script reads>"
      else
        gw_ok "$service ${E[muted]}$repo_path${E[reset]}"
      fi
    fi
  done
}

doctor_check_targets() {
  local name target_path env_var file
  print -u2
  gw_heading 'Target files'
  if [[ -z $(gw_config_entries "$GW_TARGETS") ]]; then
    doctor_warning 'No target file is set up' 'Add one with:' 'gw target add <name> <path> [ENV_VAR]'
    return
  fi
  gw_config_entries "$GW_TARGETS" | while read -r name target_path env_var; do
    file=$(gw_expand_path "$target_path")
    if [[ -f $file ]]; then
      gw_ok "$name ${E[muted]}$target_path${env_var:+ ($env_var)}${E[reset]}"
    elif [[ -n $env_var ]]; then
      doctor_warning "$name: $target_path does not exist yet; gw creates it with $env_var when needed"
    elif [[ -d ${file:h} ]]; then
      doctor_problem "$name: $target_path does not exist" 'Fix the path with:' "gw target rm $name $target_path && gw target add $name <path>"
    else
      doctor_problem "$name: the folder of $target_path does not exist" 'Fix the path with:' "gw target rm $name $target_path && gw target add $name <path>"
    fi
  done
}

doctor_check_gateways() {
  local name address result_file
  local -a names=($(gw_alias_names)) pids=()
  local -A result_files=() addresses=()
  print -u2
  gw_heading 'Gateways'
  if (( ${#names} == 0 )); then
    doctor_warning 'No gateway is saved' 'Save one with:' 'gw alias <address> <name>'
    return
  fi
  gw_prepare_ssh
  for name in "${names[@]}"; do
    addresses[$name]=$(gw_gateway_address "$name")
    gw_temp_file
    result_files[$name]=$REPLY
    doctor_ping "${addresses[$name]}" "${result_files[$name]}" &
    pids+=($!)
  done
  gw_spinner_start '' "Logging in to ${#names} gateways" /dev/null
  wait "${pids[@]}" || true
  gw_spinner_stop
  for name in "${names[@]}"; do
    doctor_report_ping "$name" "${addresses[$name]}" "${result_files[$name]}"
  done
}

doctor_ping() {
  local address=$1 result_file=$2 exit_code=0
  ssh -o BatchMode=yes -o ConnectTimeout=$GW_DOCTOR_SSH_TIMEOUT "${GW_SSH_OPTIONS[@]}" "$address" true \
    < /dev/null > /dev/null 2> "$result_file" || exit_code=$?
  print -r -- "exit=$exit_code" >> "$result_file"
}

doctor_report_ping() {
  local name=$1 address=$2 result_file=$3 output
  output=$(< "$result_file")
  if [[ $output == *exit=0* ]]; then
    gw_ok "$name ${E[muted]}$address${E[reset]}"
  elif [[ $output == *'Permission denied'* ]]; then
    doctor_problem "$name: $address does not accept your ssh key" 'Fix:' "ssh-copy-id $address"
  elif [[ $output == *'Host key verification failed'* || $output == *'REMOTE HOST IDENTIFICATION HAS CHANGED'* ]]; then
    doctor_problem "$name: the ssh host key of $address is unknown or changed" 'Check it once with:' "ssh $address"
  else
    doctor_problem "$name: cannot reach $address ${E[muted]}(${${(f)output}[1]})${E[reset]}" 'Check the VPN or network, then:' "ssh $address"
  fi
}

doctor_summary() {
  print -u2
  if (( doctor_problems > 0 )); then
    gw_error "$doctor_problems $( (( doctor_problems == 1 )) && print problem || print problems ) found; fix them with the commands above"
    exit 1
  fi
  if (( doctor_warnings > 0 )); then
    gw_ok "gw is ready to use ${E[muted]}($doctor_warnings $( (( doctor_warnings == 1 )) && print warning || print warnings ) above)${E[reset]}"
  else
    gw_ok 'gw is ready to use'
  fi
}
