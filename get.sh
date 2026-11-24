#!/usr/bin/env zsh
[ -n "${ZSH_VERSION:-}" ] || exec zsh "$0" "$@"

emulate -R zsh
setopt err_exit no_unset pipe_fail

repo=${GW_RELEASE_REPO:-Transmission-Dynamics/gateway-dev-cli}
install_dir=${GW_INSTALL_DIR:-$HOME/.local/share/gw}
wanted=${1:-latest}
label=$wanted
[[ $wanted != latest ]] || label='the latest release'

fail() {
  print -u2 -r -- "✗ $1"
  [[ -z ${2:-} ]] || print -u2 -r -- "  $2"
  exit 1
}

download_with_gh() {
  local -a tag=()
  [[ $wanted == latest ]] || tag=("$wanted")
  gh release download "${tag[@]}" --repo "$repo" --pattern 'gw-*.tar.gz' --dir "$work" ||
    fail "Could not download $label of $repo" 'Check that you can open the repo with: gh repo view '"$repo"
}

download_with_token() {
  local release=latest url name
  [[ $wanted == latest ]] || release=tags/$wanted
  curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" -o "$work/release.json" \
    "https://api.github.com/repos/$repo/releases/$release" ||
    fail "Could not read $label of $repo" 'Check that GITHUB_TOKEN can read the repo'
  url=$(plutil -extract assets.0.url raw -o - "$work/release.json") || fail "The release has no gw archive"
  name=$(plutil -extract assets.0.name raw -o - "$work/release.json")
  curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" -H 'Accept: application/octet-stream' -o "$work/$name" "$url" ||
    fail "Could not download $name"
}

work=$(mktemp -d "${${TMPDIR:-/tmp}%/}/gw-get.XXXXXX")
trap 'rm -rf "$work"' EXIT

print -u2 -r -- "==> Downloading $label of $repo"
if whence -p gh > /dev/null && gh auth status --hostname github.com > /dev/null 2>&1; then
  download_with_gh
elif [[ -n ${GITHUB_TOKEN:-} ]]; then
  download_with_token
else
  fail "$repo is private, so sign in to GitHub first" 'Run: gh auth login   (or export GITHUB_TOKEN=<a token that can read the repo>)'
fi

archives=("$work"/gw-*.tar.gz(N))
(( ${#archives} == 1 )) || fail 'The release does not contain one gw archive'
tar -xzf "${archives[1]}" -C "$work"
unpacked=("$work"/gw-*(N/))
(( ${#unpacked} == 1 )) && [[ -f ${unpacked[1]}/VERSION ]] || fail 'The gw archive has no VERSION file'
version=$(< "${unpacked[1]}/VERSION")

mkdir -p "$install_dir"
rm -rf "$install_dir/$version"
mv "${unpacked[1]}" "$install_dir/$version"
"$install_dir/$version/install.sh"

for old in "$install_dir"/*(N/); do
  [[ ${old:t} == "$version" ]] || rm -rf "$old"
done
