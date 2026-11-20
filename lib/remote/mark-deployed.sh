apps_dir=${GW_APPS_DIR:-/usr/jrd}
service=$1
name=$(printf '%s' "$2" | tr '\t\n' '  ')

cd "$apps_dir/$service" 2>/dev/null || { echo "No $apps_dir/$service on this host" >&2; exit 1; }
[ -f version ] || { echo "No version file in $apps_dir/$service" >&2; exit 1; }

{
  printf 'name=%s\n' "$name"
  printf 'commit=%s\n' "$(head -n 1 version)"
  printf 'version_mtime=%s\n' "$(stat -c %Y version)"
} > .gw-deployed-by.tmp && mv .gw-deployed-by.tmp .gw-deployed-by
