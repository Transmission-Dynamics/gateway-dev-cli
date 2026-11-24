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
