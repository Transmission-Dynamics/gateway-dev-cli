apps_dir=${GW_APPS_DIR:-/usr/jrd}

cd "$apps_dir" 2>/dev/null || { echo "No $apps_dir on this host, it does not look like a gateway" >&2; exit 1; }

if [ $# -eq 0 ]; then
  set -- $(for dir in */; do [ -f "$dir/manifest.json" ] && echo "${dir%/}"; done)
fi

for service in "$@"; do
  echo "progress: $service" >&2
  if [ ! -f "$service/manifest.json" ]; then
    printf '%s\t%s\t-\t-\n' "$service" "(no manifest)"
    continue
  fi

  tr '{},[]' '\n\n\n\n\n' < "$service/manifest.json" | awk -v service="$service" -F'"' '
    $2 == "submodules" { in_submodules = 1; next }
    $2 == "version" && !in_submodules { service_version = $4; next }
    $2 == "name" && in_submodules { name = $4; next }
    $2 == "version" && in_submodules { printf "%s\t%s\t%s\t%s\n", service, service_version, name, $4; printed = 1 }
    END { if (!printed) printf "%s\t%s\t-\t-\n", service, service_version }
  '
done
