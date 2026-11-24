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

find_with_gh() {
  local -a tag=()
  [[ $wanted == latest ]] || tag=("$wanted")
  release_tag=$(gh release view "${tag[@]}" --repo "$repo" --json tagName --jq .tagName 2> /dev/null) ||
    fail "Could not find $label of $repo" "Check that you can open the repo with: gh repo view $repo"
}

download_with_gh() {
  gh release download "$release_tag" --repo "$repo" --pattern 'gw-*.tar.gz' --dir "$work" ||
    fail "Could not download $release_tag of $repo"
}

find_with_token() {
  local release=latest
  [[ $wanted == latest ]] || release=tags/$wanted
  curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" -o "$work/release.json" \
    "https://api.github.com/repos/$repo/releases/$release" ||
    fail "Could not find $label of $repo" 'Check that GITHUB_TOKEN can read the repo'
  release_tag=$(plutil -extract tag_name raw -o - "$work/release.json")
}

download_with_token() {
  local url name
  url=$(plutil -extract assets.0.url raw -o - "$work/release.json") || fail "$release_tag has no gw archive"
  name=$(plutil -extract assets.0.name raw -o - "$work/release.json")
  curl -fsSL -H "Authorization: Bearer $GITHUB_TOKEN" -H 'Accept: application/octet-stream' -o "$work/$name" "$url" ||
    fail "Could not download $name"
}

work=$(mktemp -d "${${TMPDIR:-/tmp}%/}/gw-get.XXXXXX")
trap 'rm -rf "$work"' EXIT
release_tag=''

if whence -p gh > /dev/null && gh auth status --hostname github.com > /dev/null 2>&1; then
  source=gh
elif [[ -n ${GITHUB_TOKEN:-} ]]; then
  source=token
else
  fail 'Sign in to GitHub first, the repo needs a login' 'Run: gh auth login   (or export GITHUB_TOKEN=<a token that can read the repo>)'
fi

find_with_$source
if [[ $release_tag == "${GW_CURRENT_VERSION:-}" ]]; then
  print -u2 -r -- "✓ gw $release_tag is already installed"
  exit 0
fi
print -u2 -r -- "==> Downloading gw $release_tag from $repo"
download_with_$source

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
