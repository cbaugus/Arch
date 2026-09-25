#!/usr/bin/env bash
# install.sh -- the one-line entry point. Fetches this repo and runs setup.sh.
#
#   curl -fsSL https://raw.githubusercontent.com/cbaugus/Arch/main/install.sh | bash
#   curl -fsSL https://raw.githubusercontent.com/cbaugus/Arch/main/install.sh | bash -s -- --profile desktop
#
# Run it as your normal user (it asks for your sudo password) or as root on a
# minimal box. Anything after `--` goes to setup.sh (see ./setup.sh --help).
# Re-running it updates the checkout and re-applies, which is safe.
#
# Environment overrides: ARCH_REPO (git URL), ARCH_REF (branch or tag),
# ARCH_DIR (checkout location, default /usr/local/src/cbaugus-arch).
#
# Everything is inside main(), which runs on the last line, so a download cut
# off halfway does nothing instead of half a job.
set -euo pipefail

main() {
  local repo="${ARCH_REPO:-https://github.com/cbaugus/Arch.git}"
  local ref="${ARCH_REF:-main}"
  local dest="${ARCH_DIR:-/usr/local/src/cbaugus-arch}"
  local self="${BASH_SOURCE[0]:-}"

  [ -f /etc/arch-release ] || { echo "install.sh: this is for Arch Linux" >&2; exit 1; }

  if [ "$(id -u)" -ne 0 ]; then
    command -v sudo >/dev/null || { echo "install.sh: no sudo here; run it as root instead" >&2; exit 1; }
    echo "== elevating with sudo"
    # Works whether we came from a file or from a pipe: hand root this function.
    # Settings travel inside the script text, not as sudo env (sudoers may strip it).
    exec sudo bash -c "$(printf 'ARCH_REPO=%q ARCH_REF=%q ARCH_DIR=%q ARCH_SELF=%q\n' \
      "$repo" "$ref" "$dest" "$self"; declare -f main); main \"\$@\"" main "$@"
  fi

  # Run from a clone (./install.sh): use that clone as it is.
  self="${ARCH_SELF:-$self}"
  if [ -n "$self" ] && [ -f "$self" ] && [ -f "$(dirname "$self")/setup.sh" ]; then
    exec "$(cd "$(dirname "$self")" && pwd)/setup.sh" "$@"
  fi

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
  exec "$dest/setup.sh" "$@"
}

main "$@"
