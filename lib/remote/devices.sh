tables_dir=${GW_TABLES_DIR:-/media/sdcard/tables}
database=$tables_dir/last-device.db
since_seconds=${1:-7200}
tab=$(printf '\t')

command -v sqlite3 >/dev/null 2>&1 || { echo "sqlite3 is not installed on this gateway" >&2; exit 1; }
[ -f "$database" ] || { echo "No $database on this gateway, the transceiver has not recorded any device yet" >&2; exit 1; }

tasks='?'
if command -v mongo >/dev/null 2>&1; then
  echo "progress: reading pending tasks" >&2
  tasks=$(mongo --quiet "${GW_MONGO_DB:-remote-transceiver-dev}" --eval '
    db.tasks.aggregate([{ $group: { _id: "$uuid", commands: { $addToSet: "$command" } } }]).forEach(function (task) {
      print(task._id + "\t" + task.commands.sort().join(", "));
    });
  ' 2>/dev/null) || tasks='?'
fi

echo "progress: reading $database" >&2
devices=$(sqlite3 -readonly -separator "$tab" "$database" "
  SELECT
    json_extract(doc, '\$.uuid'),
    json_extract(doc, '\$.type'),
    json_extract(doc, '\$.rssi'),
    MAX(json_extract(doc, '\$.timestamp')) AS seen,
    CAST(ROUND((julianday('now') - julianday(MAX(json_extract(doc, '\$.timestamp')))) * 86400) AS INTEGER),
    json_extract(doc, '\$.batteryVoltage'),
    json_extract(doc, '\$.temperature')
  FROM collection
  GROUP BY json_extract(doc, '\$.uuid')
  HAVING julianday(seen) >= julianday('now') - $since_seconds / 86400.0
  ORDER BY seen DESC;
")

{ printf '%s\n' "$tasks"; echo '--'; printf '%s\n' "$devices"; } | awk -F "$tab" -v OFS="$tab" '
  !joining && $0 == "?" { unknown = 1; next }
  !joining && $0 == "--" { joining = 1; next }
  !joining { if ($1 != "") pending[$1] = $2; next }
  $0 == "" { next }
  { print $0, unknown ? "?" : ($1 in pending ? pending[$1] : "-") }
'
