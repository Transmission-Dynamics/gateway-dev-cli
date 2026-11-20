gw_command use \
  summary 'Write a gateway into the target files for good' \
  usage '[gateway] [target...]' '' \
  note 'Without target names every configured target is updated.' \
  note 'To point at a gateway only in this terminal, use gw session instead.' \
  example 'gw use alpha' \
  example 'gw use alpha frontend'

cmd_use() {
  gw_parse_arguments use "$@"
  gw_take_gateway use
  [[ -n $(gw_config_names "$GW_TARGETS") ]] ||
    gw_die_with_hint 'No targets configured.' 'Add one with:' 'gw target add <name> <path> [ENV_VAR]'
  gw_require_target_names "${gw_arguments[@]}"

  local name target_path env_var target_file before
  local -a rows=()
  gw_selected_targets "${gw_arguments[@]}" | while IFS=$'\t' read -r name target_path env_var; do
    target_file=$(gw_expand_path "$target_path")
    [[ -d ${target_file:h} ]] || gw_die "No such directory: ${target_path:h}"
    before=$(gw_read_target "$target_file" "$env_var")
    gw_write_target "$target_file" "$gw_gateway" "$env_var"
    rows+=("$name"$'\t'"$target_path${env_var:+ ($env_var)}"$'\t'"$before"$'\t'"$(gw_read_target "$target_file" "$env_var")")
  done
  print -r -- $'NAME\tPATH\tBEFORE\tAFTER\n'"${(F)rows}" | gw_table use_style_cell
}

complete_use() {
  gw_complete_gateway_then gw_complete_target_names "$@"
}

use_style_cell() {
  local column=$1 cell=$2 before=$5
  case $column in
    1) REPLY=${C[service]} ;;
    3) REPLY=${C[muted]} ;;
    4) if [[ $cell == "$before" ]]; then REPLY=${C[caution]}; else REPLY=${C[bold]}${C[green]}; fi ;;
  esac
}
