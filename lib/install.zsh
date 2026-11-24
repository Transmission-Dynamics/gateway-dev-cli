GW_ZSHRC_BLOCK_START='# >>> gw >>>'
GW_ZSHRC_BLOCK_END='# <<< gw <<<'

gw_zshrc_without_block() {
  local zshrc=$1
  [[ -f $zshrc ]] || return 0
  awk -v start="$GW_ZSHRC_BLOCK_START" -v end="$GW_ZSHRC_BLOCK_END" '
    $0 == start { inside = 1; next }
    $0 == end { inside = 0; next }
    !inside
  ' "$zshrc"
}

gw_replace_zshrc() {
  local zshrc=$1 replacement=$2
  [[ ! -f $zshrc ]] || cp -p "$zshrc" "$zshrc.before-gw"
  cat "$replacement" > "$zshrc"
  rm -f "$replacement"
}
