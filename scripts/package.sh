#!/usr/bin/env zsh
emulate -R zsh
setopt err_exit no_unset pipe_fail

version=${1:-}
[[ $version == v<->.<->.<->* ]] || { print -u2 -r -- 'Usage: scripts/package.sh <version like v1.2.3>'; exit 2; }

root=${0:A:h:h}
name=gw-$version
dist=${GW_DIST_DIR:-$root/dist}
stage=$(mktemp -d "${${TMPDIR:-/tmp}%/}/gw-package.XXXXXX")
trap 'rm -rf "$stage"' EXIT

mkdir -p "$stage/$name" "$dist"
git -C "$root" archive --worktree-attributes HEAD | tar -x -C "$stage/$name"
print -r -- "$version" > "$stage/$name/VERSION"
tar -czf "$dist/$name.tar.gz" -C "$stage" "$name"
print -r -- "$dist/$name.tar.gz"
