#!/usr/bin/env bash
# get.sh -- the curl entry point. Fetches this repo and runs install.sh.
#
#   curl -fsSL https://raw.githubusercontent.com/cbaugus/Arch/main/get.sh | sudo bash
#   curl -fsSL https://raw.githubusercontent.com/cbaugus/Arch/main/get.sh | sudo bash -s -- --profile desktop
#
# Anything after `--` is passed to install.sh (see its --help). Re-running it
# updates the checkout and re-applies, which is safe.
#
# Environment overrides: ARCH_REPO (git URL), ARCH_REF (branch or tag),
# ARCH_DIR (where the checkout lives, default /usr/local/src/cbaugus-arch).
#
# Everything is inside main(), which runs on the last line, so a download cut
# off halfway does nothing instead of half a job.
set -euo pipefail

main() {
  local repo="${ARCH_REPO:-https://github.com/cbaugus/Arch.git}"
  local ref="${ARCH_REF:-main}"
  local dest="${ARCH_DIR:-/usr/local/src/cbaugus-arch}"

  if [ "$(id -u)" -ne 0 ]; then
    echo "get.sh: needs root. Run: curl -fsSL https://raw.githubusercontent.com/cbaugus/Arch/main/get.sh | sudo bash" >&2
    exit 1
  fi
  [ -f /etc/arch-release ] || { echo "get.sh: this is for Arch Linux" >&2; exit 1; }

  command -v git >/dev/null || pacman -Syu --needed --noconfirm git

  if [ -d "$dest/.git" ]; then
    echo "== updating $dest ($ref)"
    git -C "$dest" fetch -q --depth 1 origin "$ref"
    git -C "$dest" reset -q --hard FETCH_HEAD
  else
    echo "== cloning $repo ($ref) into $dest"
    mkdir -p "$(dirname "$dest")"
    git clone -q --depth 1 --branch "$ref" "$repo" "$dest"
  fi

  exec "$dest/install.sh" "$@"
}

main "$@"
