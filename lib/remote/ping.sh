apps_dir=${GW_APPS_DIR:-/usr/jrd}

[ -d "$apps_dir" ] || { echo "No $apps_dir on this host, it does not look like a gateway" >&2; exit 1; }
