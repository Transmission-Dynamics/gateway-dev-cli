systemctl list-unit-files --no-legend --type=service 'td-*' |
  awk '$1 ~ /^td-[^@]+\.service$/ { name = $1; sub(/^td-/, "", name); sub(/\.service$/, "", name); print "unit\t" name }' | sort -u

for service in "$@"; do
  [ -n "$(journalctl -q -u "td-$service.service" -n 1 --output=cat 2>/dev/null)" ] || printf 'quiet\t%s\n' "$service"
done

oldest=$(journalctl -q --output=short-unix 2>/dev/null | head -n 1 | cut -d. -f1)
[ -z "$oldest" ] || printf 'journal_age\t%s\n' "$(( $(date -u +%s) - oldest ))"
