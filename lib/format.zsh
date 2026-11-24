gw_duration_label() {
  local -i seconds=$1
  if (( seconds < 60 )); then
    REPLY="${seconds}s"
  elif (( seconds < 3600 )); then
    printf -v REPLY '%dm %02ds' $(( seconds / 60 )) $(( seconds % 60 ))
  elif (( seconds < 86400 )); then
    printf -v REPLY '%dh %02dm' $(( seconds / 3600 )) $(( seconds % 3600 / 60 ))
  else
    printf -v REPLY '%dd %dh' $(( seconds / 86400 )) $(( seconds % 86400 / 3600 ))
  fi
}

gw_parse_duration() {
  local duration=$1
  [[ $duration =~ '^([0-9]+)([smhd]?)$' ]] || return 1
  local -A unit_seconds=(s 1 m 60 h 3600 d 86400 '' 1)
  REPLY=$(( match[1] * unit_seconds[${match[2]}] ))
  (( REPLY > 0 ))
}

gw_size_label() {
  local -i bytes=$1
  if (( bytes >= 1073741824 )); then
    printf -v REPLY '%.1f GB' $(( bytes / 1073741824.0 ))
  else
    REPLY="$(( (bytes + 524288) / 1048576 )) MB"
  fi
}

gw_shorten_path() {
  print -r -- "${1/#$HOME/~}"
}
