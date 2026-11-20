GW_BACKUP_SUFFIX=.gw-backup

typeset -ga gw_backups=() gw_created_targets=()

gw_proxy_value() {
  local address=$1
  if [[ $address == http://* || $address == https://* ]]; then
    print -r -- "$address"
  else
    print -r -- "http://$address"
  fi
}

gw_read_target() {
  local target_file=$1 env_var=${2:-} line
  if [[ ! -f $target_file ]]; then
    print -r -- '(missing)'
  elif [[ -n $env_var ]]; then
    line=$(grep -E "^${env_var}=" "$target_file" | tail -n 1) || line=''
    print -r -- "${line#*=}"
  else
    head -n 1 "$target_file"
  fi
}

gw_write_target() {
  local target_file=$1 address=$2 env_var=${3:-} value replacement
  if [[ -z $env_var ]]; then
    print -r -- "$address" > "$target_file"
    return
  fi
  value=$(gw_proxy_value "$address")
  replacement=$target_file.gw-new.$$
  [[ -f $target_file ]] || : > "$target_file"
  awk -v key="$env_var" -v value="$value" '
    index($0, key "=") == 1 { print key "=" value; found = 1; next }
    { print }
    END { if (!found) print key "=" value }
  ' "$target_file" > "$replacement"
  cat "$replacement" > "$target_file"
  rm -f "$replacement"
}

gw_require_target_names() {
  local name
  local -a known=($(gw_config_names "$GW_TARGETS"))
  for name in "$@"; do
    (( ! ${known[(Ie)$name]} )) || continue
    gw_error "Unknown target name: $name"
    gw_closest_or_prefix "$name" "${known[@]}"
    [[ -z $REPLY ]] || gw_hint 'Did you mean:' "$REPLY"
    gw_hint 'Configured targets:' 'gw target'
    exit 1
  done
}

gw_selected_targets() {
  local -a names=("$@")
  local name target_path env_var
  gw_config_entries "$GW_TARGETS" | while read -r name target_path env_var; do
    if (( ${#names} == 0 || ${names[(Ie)$name]} )); then
      printf '%s\t%s\t%s\n' "$name" "$target_path" "$env_var"
    fi
  done
}

gw_repo_target_files() {
  local repo=$1 name target_path env_var target_file
  gw_config_entries "$GW_TARGETS" | while read -r name target_path env_var; do
    [[ -z $env_var ]] || continue
    target_file=$(gw_expand_path "$target_path")
    if [[ $target_file == "$repo"/* ]]; then
      print -r -- "$target_file"
    fi
  done
}

gw_restore_leftover_backup() {
  local target_file=$1
  [[ -f $target_file$GW_BACKUP_SUFFIX ]] || return 0
  gw_warn "Restoring $(gw_shorten_path "$target_file"), left over from an interrupted deploy"
  mv -f "$target_file$GW_BACKUP_SUFFIX" "$target_file"
}

gw_backup_target() {
  local target_file=$1
  (( ! ${gw_backups[(Ie)$target_file]} && ! ${gw_created_targets[(Ie)$target_file]} )) || return 0
  gw_on_exit gw_restore_backups
  if [[ -f $target_file ]]; then
    cp -p "$target_file" "$target_file$GW_BACKUP_SUFFIX"
    gw_backups+=("$target_file")
  else
    gw_created_targets+=("$target_file")
  fi
}

gw_restore_backups() {
  local target_file
  for target_file in "${gw_backups[@]}"; do
    [[ ! -f $target_file$GW_BACKUP_SUFFIX ]] || mv -f "$target_file$GW_BACKUP_SUFFIX" "$target_file"
  done
  for target_file in "${gw_created_targets[@]}"; do
    rm -f "$target_file"
  done
  gw_backups=()
  gw_created_targets=()
}
