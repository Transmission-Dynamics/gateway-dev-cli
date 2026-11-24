gw_command update \
  summary 'Update gw to the latest release' \
  usage '[version]' 'Install the latest release, or the one given' \
  note 'Downloads the release with gh, or with curl when GITHUB_TOKEN is set.' \
  example 'gw update' \
  example 'gw update v0.2.0'

cmd_update() {
  gw_parse_arguments update "$@"
  (( ${#gw_arguments} <= 1 )) || gw_usage_error update "gw update takes at most one version, not: ${gw_arguments[*]}"
  if [[ ! -f $GW_ROOT/VERSION ]]; then
    gw_die_with_hint "gw runs from a git clone in $(gw_shorten_path "$GW_ROOT"), so it updates with git" \
      'Update with:' "git -C $(gw_shorten_path "$GW_ROOT") pull"
  fi
  GW_CURRENT_VERSION=$(< "$GW_ROOT/VERSION") exec zsh "$GW_ROOT/get.sh" "${gw_arguments[@]}"
}
