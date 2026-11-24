GW_CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/gw
GW_ALIASES=$GW_CONFIG_DIR/aliases
GW_TARGETS=$GW_CONFIG_DIR/targets
GW_REPOS=$GW_CONFIG_DIR/repos

gw_expand_path() {
  print -r -- "${1/#\~/$HOME}"
}

gw_config_entries() {
  local file=$1
  [[ -f $file ]] || return 0
  awk 'NF && $1 !~ /^#/' "$file"
}

gw_config_names() {
  gw_config_entries "$1" | awk '!seen[$1]++ { print $1 }'
}

gw_config_has() {
  local file=$1 first=$2 second=${3:-}
  [[ -f $file ]] || return 1
  awk -v a="$first" -v b="$second" '
    $1 == a && (b == "" || $2 == b) { found = 1 }
    END { exit !found }
  ' "$file"
}

gw_config_lookup() {
  local file=$1 first=$2 value
  [[ -f $file ]] || return 1
  value=$(awk -v a="$first" '$1 == a { print $2; exit }' "$file")
  [[ -n $value ]] || return 1
  print -r -- "$value"
}

gw_config_rewrite() {
  local file=$1 replacement=$1.gw-new.$$
  cat > "$replacement"
  mv -f "$replacement" "$file"
}

gw_config_remove() {
  local file=$1 first=$2 second=${3:-}
  [[ -f $file ]] || return 0
  awk -v a="$first" -v b="$second" '!($1 == a && (b == "" || $2 == b))' "$file" |
    gw_config_rewrite "$file"
}

gw_config_append() {
  local file=$1 line=$2
  mkdir -p "${file:h}"
  print -r -- "$line" >> "$file"
}

gw_config_sort() {
  local file=$1
  sort "$file" | gw_config_rewrite "$file"
}
