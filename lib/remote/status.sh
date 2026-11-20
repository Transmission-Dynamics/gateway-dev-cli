apps_dir=${GW_APPS_DIR:-/usr/jrd}
tab=$(printf '\t')

all=0
while [ $# -gt 0 ]; do
  case $1 in
    --all) all=1 ;;
    *) break ;;
  esac
  shift
done

cd "$apps_dir" 2>/dev/null || { echo "No $apps_dir on this host, it does not look like a gateway" >&2; exit 1; }

if [ $# -eq 0 ]; then
  set -- $(
    {
      for dir in */; do [ -f "$dir/version" ] && echo "${dir%/}"; done
      if [ "$all" = 1 ]; then
        systemctl list-unit-files --no-legend --type=service 'td-*' |
          awk '{ print $1 }' | sed -n 's/^td-\([^@]*\)\.service$/\1/p'
      fi
    } | sort -u
  )
fi
[ $# -gt 0 ] || exit 0

units=''
for service in "$@"; do units="$units td-$service.service"; done
states=$(
  systemctl show -p Id,LoadState,ActiveState,SubState,Type,UnitFileState,ActiveEnterTimestamp $units |
    awk -F= '
      function emit() {
        if (id == "") return
        name = id; sub(/^td-/, "", name); sub(/\.service$/, "", name)
        a = p["ActiveState"]; s = p["SubState"]
        if (p["LoadState"] == "not-found") state = "no unit"
        else if (p["LoadState"] == "masked") state = "disabled"
        else if (a == "active" || a == "reloading") state = (s == "exited") ? "done" : "running"
        else if (a == "activating") state = (s == "auto-restart") ? "crash loop" : "starting"
        else if (a == "deactivating") state = "stopping"
        else if (a == "failed") state = "crashed"
        else if (p["UnitFileState"] == "disabled") state = "disabled"
        else if (p["Type"] == "oneshot") state = "idle"
        else state = "stopped"
        since = "-"
        if (state == "running" || state == "done") {
          split(p["ActiveEnterTimestamp"], t, " ")
          if (t[2] != "") since = t[2] " " t[3] " " t[4]
        }
        print name "\t" state "\t" since
        id = ""; split("", p)
      }
      /^$/ { emit(); next }
      { key = $1; value = substr($0, length($1) + 2); p[key] = value; if (key == "Id") id = value }
      END { emit() }
    '
)

now=$(date -u +%s)
total=$#
checked=0
for service in "$@"; do
  checked=$((checked + 1))
  echo "progress: $checked/$total $service" >&2

  deployed_by='-'
  if [ -f "$service/version" ]; then
    commit=$(cut -c1-8 "$service/version")
    deployed_epoch=$(stat -c %Y "$service/version")
    deployed=$(date -u -d "@$deployed_epoch" '+%Y-%m-%d %H:%M')
    record="$service/.gw-deployed-by"
    if [ -f "$record" ] &&
      [ "$(sed -n 's/^commit=//p' "$record")" = "$(head -n 1 "$service/version")" ] &&
      [ "$(sed -n 's/^version_mtime=//p' "$record")" = "$deployed_epoch" ]; then
      deployed_by=$(sed -n 's/^name=//p' "$record")
      [ -n "$deployed_by" ] || deployed_by='-'
    fi
  else
    commit='-'
    deployed_epoch=0
    deployed='-'
  fi

  info=$(printf '%s\n' "$states" | awk -F'\t' -v s="$service" '$1 == s { print $2 "\t" $3; exit }')
  state=${info%%"$tab"*}
  since=${info#*"$tab"}
  if [ -z "$info" ] || [ "$state" = 'no unit' ]; then
    if [ -d "$service" ]; then state='not a service'; else state='not installed'; fi
    since='-'
  fi
  started='-'
  if [ "$since" != '-' ] && since_epoch=$(date -u -d "$since" +%s 2>/dev/null); then
    started=$((now - since_epoch))
    [ "$started" -ge 0 ] || started=0
  fi

  printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$deployed_epoch" "$service" "$commit" "$deployed" "$deployed_by" "$state" "$started"
done | sort -t "$tab" -k1,1nr -k2,2 | cut -f2-
