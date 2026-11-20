gw_command deploy \
  summary 'Deploy services from your local repos to a gateway' \
  usage '[gateway] <service>...' 'Deploy the working copy of each listed service' \
  usage '[gateway] <service>@<commit|tag>...' 'Deploy exactly that commit from a temporary checkout' \
  flag '-n --dry-run' 'Show what would be deployed and change nothing' \
  flag '-v --verbose' 'Stream the full build output instead of a progress line' \
  note 'Only the services you list are deployed, in the order of gw link.' \
  note 'Each repo is pointed at the gateway only while its npm run deploy runs; the target' \
  note 'file is put back afterwards, also when the deploy fails or you press Ctrl+C.' \
  note 'A pinned service@commit is built in a temporary git worktree with its own submodules' \
  note 'and npm ci, so your working copy is not touched.' \
  example 'gw deploy alpha rest-api frontend' \
  example 'gw deploy frontend@74695ef8' \
  example 'gw deploy alpha --dry-run rest-api frontend@v1.38.0'

GW_DEPLOY_COMMAND=(npm run deploy)
GW_DEPLOY_LOCAL_FILES=(.npmrc .env)

typeset -ga deploy_services=() deploy_finished=()
typeset -gA deploy_repos=() deploy_refs=() deploy_commits=() deploy_sources=() deploy_changes=() deploy_target_files=()
typeset -g deploy_worktree='' deploy_worktree_repo=''

cmd_deploy() {
  gw_parse_arguments deploy "$@"
  deploy_take_gateway
  (( ${#gw_arguments} > 0 )) || gw_usage_error deploy 'No services given, nothing deployed.'
  deploy_select "${gw_arguments[@]}"
  deploy_resolve_sources

  if gw_has_flag --dry-run; then
    deploy_print_plan
    return
  fi
  if gw_has_flag --verbose; then GW_VERBOSE=1; fi

  gw_require_reachable
  gw_on_exit deploy_cleanup
  local service
  for service in "${deploy_services[@]}"; do
    if [[ -n ${deploy_refs[$service]:-} ]]; then
      deploy_pinned_commit "$service"
    else
      deploy_working_copy "$service"
    fi
    deploy_finished+=("$service")
  done

  print -u2
  gw_show_status "${deploy_finished[@]}" || exit 1
}

complete_deploy() {
  gw_complete_gateway_then gw_complete_linked_services "$@"
}

deploy_take_gateway() {
  local first=${gw_arguments[1]:-}
  if [[ $first == *@* ]] && ! gw_is_alias "$first"; then
    if gw_config_has "$GW_REPOS" "${first%%@*}"; then
      gw_use_session_gateway deploy
      return
    fi
    deploy_reject_misspelled_service "$first"
  fi
  gw_take_gateway deploy
}

deploy_reject_misspelled_service() {
  local argument=$1 name=${1%%@*}
  gw_closest_or_prefix "$name" $(gw_config_names "$GW_REPOS")
  [[ -n $REPLY ]] || return 0
  gw_error "$argument looks like service@commit, but no service named $name is linked."
  gw_hint 'Did you mean:' "$REPLY@${argument#*@}"
  exit 2
}

deploy_require_linked() {
  local service=$1
  shift
  (( ! ${@[(Ie)$service]} )) || return 0
  gw_error "Unknown service: $service"
  gw_closest_or_prefix "$service" "$@"
  [[ -z $REPLY ]] || gw_hint 'Did you mean:' "$REPLY"
  if [[ -n ${1:-} ]]; then
    gw_note "Linked services: ${(j:, :)@}"
  else
    gw_hint 'Link a service to its repo with:' 'gw link <service> <path>'
  fi
  exit 1
}

deploy_select() {
  local argument service
  local -a requested=() linked=($(gw_config_names "$GW_REPOS"))
  for argument in "$@"; do
    service=${argument%%@*}
    deploy_require_linked "$service" "${linked[@]}"
    if [[ $argument == *@* ]]; then
      [[ -n ${argument#*@} ]] || gw_usage_error deploy "Missing commit or tag after @ in: $argument"
      deploy_refs[$service]=${argument#*@}
    fi
    requested+=("$service")
  done
  for service in "${linked[@]}"; do
    (( ${requested[(Ie)$service]} )) || continue
    deploy_services+=("$service")
    deploy_repos[$service]=$(gw_expand_path "$(gw_config_lookup "$GW_REPOS" "$service")")
  done
}

deploy_resolve_sources() {
  local service repo short_repo commit
  for service in "${deploy_services[@]}"; do
    repo=${deploy_repos[$service]}
    short_repo=$(gw_shorten_path "$repo")
    git -C "$repo" rev-parse --git-dir > /dev/null 2>&1 ||
      gw_die_with_hint "The repo linked to $service is not a git repository: $short_repo" \
        'Fix the link with:' "gw link $service <path>"

    deploy_target_files[$service]=$(gw_repo_target_files "$repo")
    [[ -n ${deploy_target_files[$service]} ]] ||
      gw_die_with_hint "No target file is configured inside $short_repo, so $service cannot be pointed at a gateway." \
        'Add it with:' "gw target add $service <path to the file with the deploy address>"

    if [[ -n ${deploy_refs[$service]:-} ]]; then
      commit=$(git -C "$repo" rev-parse --verify --quiet "${deploy_refs[$service]}^{commit}") ||
        gw_die_with_hint "${deploy_refs[$service]} is not a commit or tag in $short_repo." \
          'Fetch it first:' "git -C $short_repo fetch --tags"
      deploy_sources[$service]=$(git -C "$repo" describe --tags --always "$commit")
      deploy_changes[$service]=0
    else
      commit=$(git -C "$repo" rev-parse --verify --quiet HEAD) ||
        gw_die "$short_repo has no commits yet, nothing to deploy for $service."
      deploy_sources[$service]=$(git -C "$repo" branch --show-current)
      [[ -n ${deploy_sources[$service]} ]] || deploy_sources[$service]='detached HEAD'
      deploy_changes[$service]=$(git -C "$repo" status --porcelain | wc -l | tr -d ' ')
    fi
    deploy_commits[$service]=$commit
  done
}

deploy_working_copy_label() {
  local service=$1
  if [[ -n ${deploy_refs[$service]:-} ]]; then
    print -r -- 'temporary checkout'
  elif (( deploy_changes[$service] > 0 )); then
    print -r -- "${deploy_changes[$service]} uncommitted"
  else
    print -r -- 'clean'
  fi
}

deploy_print_plan() {
  local service line reachable=1
  local -a fields
  local -A deployed_now=()

  if gw_remote "Reading what is deployed on $gw_gateway" status "${deploy_services[@]}"; then
    for line in "${(@f)gw_remote_output}"; do
      [[ -n $line ]] || continue
      fields=("${(@ps:\t:)line}")
      deployed_now[${fields[1]}]=${fields[2]}
    done
  else
    reachable=0
  fi

  gw_heading "Dry run, nothing is changed ${E[reset]}${E[muted]}(a real run would execute ${GW_DEPLOY_COMMAND[*]} for $gw_gateway)"
  {
    printf 'SERVICE\tSOURCE\tCOMMIT\tDEPLOYED NOW\tWORKING COPY\n'
    for service in "${deploy_services[@]}"; do
      printf '%s\t%s\t%s\t%s\t%s\n' "$service" "${deploy_sources[$service]}" \
        "${deploy_commits[$service][1,8]}" "${deployed_now[$service]:-?}" \
        "$(deploy_working_copy_label "$service")"
    done
  } | gw_table deploy_style_plan_cell

  (( reachable )) || exit 1
}

deploy_style_plan_cell() {
  local column=$1 cell=$2 commit=$5
  case $column in
    1) REPLY=${C[service]} ;;
    2) REPLY=${C[branch]} ;;
    3) REPLY=${C[commit]} ;;
    4) if [[ $cell == "$commit" ]]; then REPLY=${C[good]}; else REPLY=${C[muted]}; fi ;;
    5) if [[ $cell == *uncommitted ]]; then REPLY=${C[bold]}${C[yellow]}; else REPLY=${C[muted]}; fi ;;
  esac
}

deploy_heading() {
  local service=$1
  gw_heading "Deploying ${E[service]}$service${E[reset]} ${E[branch]}${deploy_sources[$service]}${E[reset]} ${E[commit]}@ ${deploy_commits[$service][1,8]}${E[reset]} ${E[muted]}from $(gw_shorten_path "${deploy_repos[$service]}") to${E[reset]} ${E[address]}$gw_gateway${E[reset]}"
}

deploy_succeeded() {
  local service=$1 started=$2
  gw_ok "${E[bold]}Deployed ${E[service]}$service${E[reset]} ${E[commit]}@ ${deploy_commits[$service][1,8]}${E[reset]} ${E[muted]}in $(gw_elapsed "$started")${E[reset]}"
}

deploy_working_copy() {
  local service=$1 repo=${deploy_repos[$1]} started=$SECONDS target_file
  local -a target_files=("${(@f)deploy_target_files[$service]}")

  deploy_heading "$service"
  if (( deploy_changes[$service] > 0 )); then
    gw_warn "$GW_STEP_INDENT${deploy_changes[$service]} uncommitted changes are deployed too; gw status will still show ${deploy_commits[$service][1,8]}"
  fi

  for target_file in "${target_files[@]}"; do
    gw_restore_leftover_backup "$target_file"
  done
  for target_file in "${target_files[@]}"; do
    gw_backup_target "$target_file"
    gw_write_target "$target_file" "$gw_gateway"
  done

  gw_run_step "Building and deploying (${GW_DEPLOY_COMMAND[*]})" \
    gw_in_dir "$repo" "${GW_DEPLOY_COMMAND[@]}" || deploy_failed "$service"

  gw_restore_backups
  deploy_record "$service"
  deploy_succeeded "$service" "$started"
}

deploy_pinned_commit() {
  local service=$1 repo=${deploy_repos[$1]} commit=${deploy_commits[$1]} started=$SECONDS
  local file target_file relative_path
  local -a copied=() install=(npm ci)

  deploy_heading "$service"
  gw_note "${GW_STEP_INDENT}Built in a temporary checkout; your working copy is not touched"

  deploy_worktree_repo=$repo
  deploy_worktree=$(mktemp -d "$(gw_temp_root)/gw-deploy-$service.XXXXXX")

  gw_run_step "[1/5] Checking out ${commit[1,8]}" \
    git -C "$repo" worktree add --detach "$deploy_worktree" "$commit" || deploy_failed "$service"

  if [[ -f $deploy_worktree/.gitmodules ]]; then
    gw_run_step '[2/5] Fetching submodules' \
      git -C "$deploy_worktree" submodule update --init --recursive || deploy_failed "$service"
  else
    gw_step_done '[2/5] No submodules'
  fi

  for file in "${GW_DEPLOY_LOCAL_FILES[@]}"; do
    if [[ -f $repo/$file && ! -e $deploy_worktree/$file ]]; then
      cp -p "$repo/$file" "$deploy_worktree/$file"
      copied+=("$file")
    fi
  done
  (( ${#copied} == 0 )) || gw_note "${GW_STEP_INDENT}Copied ${(j:, :)copied} from your working copy"
  for target_file in "${(@f)deploy_target_files[$service]}"; do
    relative_path=${target_file#$repo/}
    mkdir -p "$deploy_worktree/${relative_path:h}"
    gw_write_target "$deploy_worktree/$relative_path" "$gw_gateway"
  done

  [[ -f $deploy_worktree/package-lock.json ]] || install=(npm install)
  gw_run_step "[3/5] Installing dependencies (${install[*]})" \
    gw_in_dir "$deploy_worktree" "${install[@]}" || deploy_failed "$service"

  gw_run_step "[4/5] Building and deploying (${GW_DEPLOY_COMMAND[*]})" \
    gw_in_dir "$deploy_worktree" "${GW_DEPLOY_COMMAND[@]}" || deploy_failed "$service"

  gw_run_step '[5/5] Removing the temporary checkout' deploy_remove_worktree || true

  deploy_record "$service"
  deploy_succeeded "$service" "$started"
}

deploy_record() {
  local service=$1 name
  name=$(git -C "${deploy_repos[$service]}" config user.name 2> /dev/null) || name=${USER:-unknown}
  gw_remote "Recording who deployed $service" mark-deployed "$service" "$name" ||
    gw_warn "Could not record who deployed $service, gw status will show - for it"
}

deploy_failed() {
  local service=$1 position
  local -a not_started
  deploy_cleanup
  position=${deploy_services[(Ie)$service]}
  not_started=("${(@)deploy_services[position + 1,-1]}")

  print -u2
  gw_error "Deploy of $service failed, stopping."
  (( ${#not_started} == 0 )) || gw_note "Not started: ${(j:, :)not_started}"
  if (( ${#deploy_finished} > 0 )); then
    gw_note "Already deployed in this run: ${(j:, :)deploy_finished}"
    print -u2
    gw_show_status "${deploy_finished[@]}" || true
  fi
  exit 1
}

deploy_remove_worktree() {
  [[ -n $deploy_worktree ]] || return 0
  git -C "$deploy_worktree_repo" worktree remove --force "$deploy_worktree" > /dev/null 2>&1 ||
    rm -rf "$deploy_worktree"
  git -C "$deploy_worktree_repo" worktree prune > /dev/null 2>&1 || true
  deploy_worktree=''
}

deploy_cleanup() {
  gw_restore_backups
  deploy_remove_worktree
}
