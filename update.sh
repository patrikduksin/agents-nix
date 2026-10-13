#!/usr/bin/env bash
# Pin sources.json to the newest nightly release. Hashes come from the
# release's SHA256SUMS, so nothing big is downloaded.
set -euo pipefail
cd "$(dirname "$0")"

repo=pingdotgg/t3code
tag=$(curl -fsSL ${GITHUB_TOKEN:+-H "Authorization: Bearer $GITHUB_TOKEN"} \
  "https://api.github.com/repos/$repo/releases?per_page=50" |
  jq -r '[.[] | select(.draft | not) | select(.tag_name | test("-nightly\\."))][0].tag_name')
version=${tag#v}

if [ "$version" = "$(jq -r .version sources.json)" ]; then
  echo "already at $version"
  exit 0
fi

sums=$(curl -fsSL "https://github.com/$repo/releases/download/$tag/SHA256SUMS")
sri() {
  local hex
  hex=$(awk -v f="t3-$version-$1.tar.gz" '$2 == f { print $1 }' <<<"$sums")
  [ -n "$hex" ] || { echo "no checksum for $1 in $tag" >&2; exit 1; }
  echo "sha256-$(xxd -r -p <<<"$hex" | base64 -w0)"
}

jq -n --arg v "$version" \
  --arg lx "$(sri linux-x64)" --arg la "$(sri linux-arm64)" --arg da "$(sri darwin-arm64)" '{
    version: $v,
    platforms: {
      "x86_64-linux": { name: "linux-x64", hash: $lx },
      "aarch64-linux": { name: "linux-arm64", hash: $la },
      "aarch64-darwin": { name: "darwin-arm64", hash: $da }
    }
  }' >sources.json
echo "updated to $version"
