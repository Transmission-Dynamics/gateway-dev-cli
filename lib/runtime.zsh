GW_ISSUES_URL=https://github.com/Transmission-Dynamics/gateway-dev-cli/issues

typeset -ga GW_EXIT_HOOKS=()
exec {GW_STDERR_FD}>&2

gw_on_exit() {
  (( ${GW_EXIT_HOOKS[(Ie)$1]} )) || GW_EXIT_HOOKS+=("$1")
}

gw_run_exit_hooks() {
  (( ZSH_SUBSHELL == 0 )) || return 0
  local hook
  for hook in "${(@Oa)GW_EXIT_HOOKS}"; do
    "$hook" || true
  done
  GW_EXIT_HOOKS=()
}

gw_interrupted() {
  (( ZSH_SUBSHELL == 0 )) || exit 130
  gw_run_exit_hooks
  print -u2
  gw_error 'Interrupted'
  exit 130
}

TRAPZERR() {
  (( ZSH_SUBSHELL == 0 )) || exit 1
  gw_error "Unexpected failure at ${funcfiletrace[1]#$GW_ROOT/}"
  gw_note 'This is a bug in gw. Please report it with the command you ran:'
  gw_note "  $GW_ISSUES_URL"
  exit 1
}

trap gw_run_exit_hooks EXIT
TRAPINT() {
  gw_interrupted 2>&$GW_STDERR_FD
}

TRAPTERM() {
  gw_interrupted 2>&$GW_STDERR_FD
}
