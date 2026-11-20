#!/usr/bin/env zsh
[ -n "${ZSH_VERSION:-}" ] || exec zsh "$0" "$@"

emulate -R zsh
setopt err_exit no_unset pipe_fail

GW_ROOT=${0:A:h}
source "$GW_ROOT/lib/ui.zsh"
source "$GW_ROOT/lib/install.zsh"

BIN_DIR=$HOME/.local/bin
CONFIG_DIR=${XDG_CONFIG_HOME:-$HOME/.config}/gw
ZSHRC=${ZDOTDIR:-$HOME}/.zshrc

gw_heading 'Installing gw'

mkdir -p "$BIN_DIR"
if [[ -e $BIN_DIR/gw && ! -L $BIN_DIR/gw ]]; then
  mv "$BIN_DIR/gw" "$BIN_DIR/gw.before-install"
  gw_warn "Moved the existing $(gw_install_path "$BIN_DIR/gw") to gw.before-install"
fi
ln -sfn "$GW_ROOT/bin/gw" "$BIN_DIR/gw"
gw_ok "Linked $(gw_install_path "$BIN_DIR/gw") ${E[muted]}→${E[reset]} $(gw_install_path "$GW_ROOT/bin/gw")"

gw_zshrc_without_block "$ZSHRC" > "$ZSHRC.gw-new"
{
  print -r -- "$GW_ZSHRC_BLOCK_START"
  print -r -- "[[ -r ${(q)GW_ROOT}/shell/gw.zsh ]] && source ${(q)GW_ROOT}/shell/gw.zsh"
  print -r -- "$GW_ZSHRC_BLOCK_END"
} >> "$ZSHRC.gw-new"
if [[ -f $ZSHRC ]] && cmp -s "$ZSHRC" "$ZSHRC.gw-new"; then
  rm -f "$ZSHRC.gw-new"
  gw_ok "$(gw_install_path "$ZSHRC") already loads the shell integration"
else
  gw_replace_zshrc "$ZSHRC" "$ZSHRC.gw-new"
  gw_ok "Added the shell integration to $(gw_install_path "$ZSHRC") ${E[muted]}(sessions, prompt, tab completion)${E[reset]}"
  [[ ! -f $ZSHRC.before-gw ]] || gw_note "The previous version is in $(gw_install_path "$ZSHRC.before-gw")"
fi
if gw_zshrc_without_block "$ZSHRC" | grep -q '^gw()'; then
  gw_warn "$(gw_install_path "$ZSHRC") also defines gw() by hand; it is overridden now and can be deleted"
fi

mkdir -p "$CONFIG_DIR"
for file in aliases targets repos; do
  if [[ -e $CONFIG_DIR/$file ]]; then
    gw_note "  Kept your $(gw_install_path "$CONFIG_DIR/$file")"
  else
    cp "$GW_ROOT/examples/$file" "$CONFIG_DIR/$file"
    gw_ok "Created $(gw_install_path "$CONFIG_DIR/$file") from the example"
  fi
done

print -u2
gw_ok "${E[bold]}gw is installed${E[reset]}"
gw_hint 'Open a new terminal, then try:' 'gw --help'
