typeset -gA C E I

GW_PLACEHOLDER_CELLS=('-' '?' '(missing)' '(no manifest)')

gw_color_enabled() {
  local fd=$1
  [[ -z ${NO_COLOR:-} ]] || return 1
  case ${GW_COLOR:-auto} in
    always) return 0 ;;
    never) return 1 ;;
  esac
  [[ -t $fd ]]
}

gw_set_palette() {
  local name=$1 fd=$2 key
  local -A codes=(
    reset $'\e[0m' bold $'\e[1m' underline $'\e[4m'
    red $'\e[31m' green $'\e[32m' yellow $'\e[33m' blue $'\e[34m'
    magenta $'\e[35m' cyan $'\e[36m' gray $'\e[90m'
  )
  codes+=(
    title "${codes[bold]}${codes[underline]}"
    service "${codes[bold]}${codes[cyan]}"
    address "${codes[bold]}${codes[cyan]}"
    command "${codes[cyan]}"
    commit "${codes[yellow]}"
    argument "${codes[yellow]}"
    branch "${codes[magenta]}"
    person "${codes[magenta]}"
    variable "${codes[magenta]}"
    muted "${codes[gray]}"
    good "${codes[green]}"
    caution "${codes[yellow]}"
    bad "${codes[bold]}${codes[red]}"
  )
  if ! gw_color_enabled "$fd"; then
    for key in ${(k)codes}; do codes[$key]=''; done
  fi
  set -A "$name" "${(@kv)codes}"
}

gw_set_palette C 1
gw_set_palette E 2

gw_set_icons() {
  if gw_color_enabled 2 && [[ ${GW_EMOJI:-auto} != never ]]; then
    I=(ok ✅ warn ⚠️ error ❌ heading 🔹 hint 💡 gateway 📡 step ▶️)
  else
    I=(ok ✓ warn ! error ✗ heading '==>' hint '' gateway '' step ▸)
  fi
}

gw_set_icons

gw_info() {
  print -u2 -r -- "$*"
}

gw_note() {
  print -u2 -r -- "${E[muted]}$*${E[reset]}"
}

gw_heading() {
  print -u2 -r -- "${E[bold]}${E[blue]}${I[heading]}${E[reset]} ${E[bold]}$*${E[reset]}"
}

gw_ok() {
  print -u2 -r -- "${E[good]}${I[ok]}${E[reset]} $*"
}

gw_warn() {
  print -u2 -r -- "${E[caution]}${I[warn]} $*${E[reset]}"
}

gw_error() {
  print -u2 -r -- "${E[bad]}${I[error]} $*${E[reset]}"
}

gw_die() {
  gw_error "$@"
  exit 1
}

gw_hint() {
  print -u2 -r -- "${I[hint]:+${I[hint]} }${E[muted]}$1${E[reset]} ${E[command]}$2${E[reset]}"
}

gw_quote_lines() {
  local indent=${1:-}
  local line
  while IFS= read -r line; do
    print -u2 -r -- "$indent  ${E[muted]}│ $line${E[reset]}"
  done
}

gw_join() {
  local separator=$1
  shift
  print -r -- "${(pj:$separator:)@}"
}

gw_table() {
  local styler=${1:-gw_style_first_column}
  local -a rows widths cells
  local line cell blank='' column padding row=0 REPLY gw_styled_cell

  while IFS= read -r line; do
    [[ -n $line ]] || continue
    rows+=("$line")
    cells=("${(@ps:\t:)line}")
    for (( column = 1; column <= $#cells; column++ )); do
      if (( ${#cells[column]} > ${widths[column]:-0} )); then
        widths[column]=${#cells[column]}
      fi
    done
  done

  for line in "${rows[@]}"; do
    row=$(( row + 1 ))
    cells=("${(@ps:\t:)line}")
    for (( column = 1; column <= $#cells; column++ )); do
      cell=${cells[column]}
      REPLY=''
      gw_styled_cell=''
      if (( row == 1 )); then
        REPLY=${C[title]}
      elif [[ -z ${cell// } ]] || (( ${GW_PLACEHOLDER_CELLS[(Ie)$cell]} )); then
        REPLY=${C[muted]}
      else
        "$styler" "$column" "$cell" "${cells[@]}"
      fi
      if [[ -n $gw_styled_cell ]]; then
        print -n -r -- "$gw_styled_cell"
      else
        print -n -r -- "${REPLY}${cell}${REPLY:+${C[reset]}}"
      fi
      if (( column < $#cells )); then
        padding=$(( widths[column] - ${#cell} + 2 ))
        print -n -r -- "${(l:padding:)blank}"
      fi
    done
    print
  done
}

gw_style_first_column() {
  if (( $1 == 1 )); then REPLY=${C[service]}; fi
}

gw_die_with_hint() {
  gw_error "$1"
  gw_hint "$2" "$3"
  exit 1
}
