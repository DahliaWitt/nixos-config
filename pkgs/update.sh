#!/usr/bin/env bash
# Bump flake inputs and the pinned packages in pkgs/ to their latest releases.
# Needs Nix, curl and jq, so run it on nixos-btw (the scheduled update does).
set -euo pipefail
cd "$(dirname "$0")/.."

nix flake update

# t3: latest stable release (nightlies are GitHub pre-releases, so /latest
# skips them).
latest=$(curl -fsSL https://api.github.com/repos/pingdotgg/t3code/releases/latest | jq -r .tag_name)
latest=${latest#v}
current=$(sed -n 's/^  version = "\(.*\)";$/\1/p' pkgs/t3.nix)
if [ -n "$latest" ] && [ "$latest" != "$current" ]; then
  url="https://github.com/pingdotgg/t3code/releases/download/v$latest/t3-$latest-linux-x64.tar.gz"
  hash=$(nix store prefetch-file --json "$url" | jq -r .hash)
  sed -i -e "s|^  version = \".*\";\$|  version = \"$latest\";|" \
         -e "s|^    hash = \".*\";\$|    hash = \"$hash\";|" pkgs/t3.nix
  echo "t3: $current -> $latest"
fi
