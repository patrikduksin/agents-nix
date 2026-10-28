#!/usr/bin/env bash
# Pin each package's sources.json to its newest release. Hashes come from the
# publishers' own checksums, so nothing big is downloaded.
#   ./update.sh                 all packages
#   ./update.sh codex t3code    just these
set -euo pipefail
cd "$(dirname "$0")"

gh_api() { curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} "https://api.github.com/$1"; }
hex2sri() { echo "sha256-$(xxd -r -p <<<"$1" | base64 -w0)"; }
current() { jq -r .version "pkgs/$1/sources.json"; }

# write <pkg> <version> then "<system> <platform name> <hex sha256>" lines on stdin
write() {
  local pkg=$1 version=$2 platforms='{}' system name hex
  while read -r system name hex; do
    [ -n "$hex" ] && [ "$hex" != null ] || { echo "$pkg: no checksum for $name" >&2; exit 1; }
    platforms=$(jq --arg s "$system" --arg n "$name" --arg h "$(hex2sri "$hex")" \
      '. + {($s): {name: $n, hash: $h}}' <<<"$platforms")
  done
  jq -n --arg v "$version" --argjson p "$platforms" '{version: $v, platforms: $p}' >"pkgs/$pkg/sources.json"
  echo "$pkg: updated to $version"
}

update_t3code() {
  local repo=pingdotgg/t3code tag version sums
  tag=$(gh_api "repos/$repo/releases?per_page=50" |
    jq -r '[.[] | select(.draft | not) | select(.tag_name | test("-nightly\\."))][0].tag_name')
  version=${tag#v}
  [ "$version" != "$(current t3code)" ] || { echo "t3code: already at $version"; return; }
  sums=$(curl -fsSL "https://github.com/$repo/releases/download/$tag/SHA256SUMS")
  for p in x86_64-linux:linux-x64 aarch64-linux:linux-arm64 aarch64-darwin:darwin-arm64; do
    echo "${p%%:*} ${p#*:} $(awk -v f="t3-$version-${p#*:}.tar.gz" '$2 == f { print $1 }' <<<"$sums")"
  done | write t3code "$version"
}

update_claude-code() {
  local base=https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases
  local version manifest
  version=$(curl -fsSL "$base/latest")
  [ "$version" != "$(current claude-code)" ] || { echo "claude-code: already at $version"; return; }
  manifest=$(curl -fsSL "$base/$version/manifest.json")
  for p in x86_64-linux:linux-x64 aarch64-linux:linux-arm64 aarch64-darwin:darwin-arm64; do
    echo "${p%%:*} ${p#*:} $(jq -r --arg n "${p#*:}" '.platforms[$n].checksum' <<<"$manifest")"
  done | write claude-code "$version"
}

update_codex() {
  local release version
  release=$(gh_api repos/openai/codex/releases/latest) # stable only, no alphas
  version=$(jq -r '.tag_name | ltrimstr("rust-v")' <<<"$release")
  [ "$version" != "$(current codex)" ] || { echo "codex: already at $version"; return; }
  for p in x86_64-linux:x86_64-unknown-linux-musl aarch64-linux:aarch64-unknown-linux-musl aarch64-darwin:aarch64-apple-darwin; do
    echo "${p%%:*} ${p#*:} $(jq -r --arg f "codex-package-${p#*:}.tar.gz" \
      '.assets[] | select(.name == $f) | .digest | ltrimstr("sha256:")' <<<"$release")"
  done | write codex "$version"
}

pkgs=("$@")
[ ${#pkgs[@]} -gt 0 ] || pkgs=(t3code claude-code codex)
for pkg in "${pkgs[@]}"; do "update_$pkg"; done
