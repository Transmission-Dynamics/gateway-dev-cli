failed=0
for service in "$@"; do
  unit="td-$service.service"
  echo "progress: $unit" >&2
  if ! systemctl cat "$unit" >/dev/null 2>&1; then
    echo "No unit $unit on this gateway, skipped" >&2
    failed=1
    continue
  fi
  if ! sudo systemctl restart "$unit"; then
    echo "Failed to restart $unit" >&2
    failed=1
  fi
done
exit $failed
