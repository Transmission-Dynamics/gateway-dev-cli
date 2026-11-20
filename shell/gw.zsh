GW_HOME=${${(%):-%x}:A:h:h}

gw() {
  if [[ ${1:-} != session ]]; then
    "$GW_HOME/bin/gw" "$@"
    return
  fi
  local gw_session_code
  gw_session_code=$("$GW_HOME/bin/gw" "$@") || return
  eval "$gw_session_code"
}

_gw() {
  local line value
  local -a candidates=()
  local -i offer_files=0 offer_directories=0
  for line in "${(@f)$("$GW_HOME/bin/gw" __complete "${(@)words[2,CURRENT-1]}" 2> /dev/null)}"; do
    case $line in
      '') ;;
      :files) offer_files=1 ;;
      :directories) offer_directories=1 ;;
      *)
        value=${line%%$'\t'*}
        candidates+=("${value//:/\\:}:${line#*$'\t'}")
        ;;
    esac
  done
  (( ${#candidates} == 0 )) || _describe -t gw 'gw' candidates
  (( ! offer_files )) || _files
  (( ! offer_directories )) || _files -/
}

_gw_register_completion() {
  (( $+functions[compdef] )) || return 0
  compdef _gw gw
  add-zsh-hook -d precmd _gw_register_completion
}

autoload -Uz add-zsh-hook
add-zsh-hook precmd _gw_register_completion

setopt prompt_subst
if [[ ${RPROMPT:-} != *GW_SESSION* ]]; then
  RPROMPT='%F{yellow}${GW_SESSION:+[gw:$GW_SESSION_LABEL]}%f'${RPROMPT:-}
fi
