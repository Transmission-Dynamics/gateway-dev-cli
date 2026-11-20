tables_dir=${GW_TABLES_DIR:-/media/sdcard/tables}
proc_dir=${GW_PROC_DIR:-/proc}

printf 'uptime\t%s\n' "$(cut -d. -f1 "$proc_dir/uptime")"
printf 'load\t%s\t%s\n' "$(cut -d' ' -f1-3 "$proc_dir/loadavg")" "$(nproc)"
awk '/^MemTotal:/ { total = $2 } /^MemAvailable:/ { available = $2 } END { printf "memory\t%d\t%d\n", total, available }' "$proc_dir/meminfo"

for mount in "$tables_dir" /; do
  df -Pk "$mount" 2>/dev/null | awk -v mount="$mount" 'NR == 2 { printf "disk\t%s\t%d\t%d\n", mount, $2, $3 }'
done
