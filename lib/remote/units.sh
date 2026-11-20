systemctl list-unit-files --no-legend --type=service 'td-*' |
  awk '{ print $1 }' | sed -n 's/^td-\([^@]*\)\.service$/\1/p' | sort -u
