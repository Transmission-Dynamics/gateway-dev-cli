#!/usr/bin/env zsh
emulate -R zsh
setopt err_exit no_unset pipe_fail

version=${1:-}
[[ $version == v<->.<->.<->* ]] || { print -u2 -r -- 'Usage: scripts/set-readme-release.sh <version like v1.2.3>'; exit 2; }

readme=${GW_README:-${0:A:h:h}/README.md}
repo_url=https://github.com/${GW_RELEASE_REPO:-Transmission-Dynamics/gateway-dev-cli}
line="**Latest release:** [$version]($repo_url/releases/tag/$version)"

grep -q '^\*\*Latest release:\*\*' "$readme" || { print -u2 -r -- "No **Latest release:** line in $readme"; exit 1; }
awk -v line="$line" '/^\*\*Latest release:\*\*/ { print line; next } { print }' "$readme" > "$readme.new"
mv "$readme.new" "$readme"
