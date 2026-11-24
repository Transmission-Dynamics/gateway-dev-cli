#!/usr/bin/env zsh
[ -n "${ZSH_VERSION:-}" ] || exec zsh "$0" "$@"

emulate -R zsh
setopt err_exit no_unset pipe_fail

GW_ROOT=${0:A:h}
source "$GW_ROOT/lib/ui.zsh"
source "$GW_ROOT/lib/format.zsh"
source "$GW_ROOT/lib/install.zsh"

BIN_DIR=$HOME/.local/bin
CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/gw
ZSHRC=${ZDOTDIR:-$HOME}/.zshrc

gw_heading 'Uninstalling gw'

if [[ -L $BIN_DIR/gw ]]; then
  rm "$BIN_DIR/gw"
  gw_ok "Removed $(gw_shorten_path "$BIN_DIR/gw")"
fi

if [[ -f $ZSHRC ]] && grep -qxF "$GW_ZSHRC_BLOCK_START" "$ZSHRC"; then
  gw_zshrc_without_block "$ZSHRC" > "$ZSHRC.gw-new"
  gw_replace_zshrc "$ZSHRC" "$ZSHRC.gw-new"
  gw_ok "Removed the shell integration from $(gw_shorten_path "$ZSHRC")"
fi

gw_note "Your config in $(gw_shorten_path "$CONFIG_DIR") was kept; delete it by hand if you want."
