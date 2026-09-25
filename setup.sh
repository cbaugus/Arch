#!/usr/bin/env bash
# setup.sh -- turn a fresh Arch install into one of our machines.
#
#   curl -fsSL https://raw.githubusercontent.com/cbaugus/Arch/main/install.sh | bash
#   or, from a clone:  ./install.sh [options]   (install.sh fetches, elevates, runs this)
#
# Options:
#   --profile headless-vnc   (default) Hyprland on a virtual display, reached only
#                            over the tailnet with wayvnc (no monitor needed)
#   --profile desktop        packages, bar, themes and shell only; no VNC services
#   --user NAME              who gets the desktop (default: the user who ran sudo,
#                            or the only regular user when run as root)
#   --theme NAME             starting theme on first install (default: tokyo-night)
#   --no-aur                 skip packages/aur.txt
#
# Safe to re-run: packages are --needed, files are re-deployed (a differing file
# is backed up once as <file>.pre-labs), and existing secrets are kept.
# Secrets never come from this repo: the wayvnc password is prompted for.
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd /   # never depend on the caller's cwd (a sudo -u from /root broke find once)

PROFILE=headless-vnc; USER_NAME="${SUDO_USER:-}"; THEME=tokyo-night; AUR=1
while [ $# -gt 0 ]; do
  case "$1" in
    --profile) PROFILE="$2"; shift 2 ;;
    --user)    USER_NAME="$2"; shift 2 ;;
    --theme)   THEME="$2"; shift 2 ;;
    --no-aur)  AUR=0; shift ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
done

die()  { echo "setup.sh: $*" >&2; exit 1; }
step() { printf '\n== %s\n' "$*"; }
note() { printf '   %s\n' "$*"; }
pkgs() { grep -vE '^[[:space:]]*(#|$)' "$HERE/packages/$1.txt" || true; }
as_user() { runuser -u "$USER_NAME" -- "$@"; }   # util-linux: works before sudo exists

[ "$(id -u)" -eq 0 ] || die "run as root (install.sh does this for you)"
[ -f /etc/arch-release ] || die "this is for Arch Linux"
case "$PROFILE" in headless-vnc|desktop) ;; *) die "unknown profile: $PROFILE" ;; esac
if [ -z "$USER_NAME" ]; then   # run as root, e.g. on a minimal box: take the only regular user
  mapfile -t humans < <(getent passwd | awk -F: '$3>=1000 && $3<60000 {print $1}')
  [ "${#humans[@]}" -eq 1 ] && USER_NAME="${humans[0]}"
  [ -n "$USER_NAME" ] || die "no single regular user to set up. Create one (useradd -m -G wheel NAME && passwd NAME) or pass --user NAME"
fi
id "$USER_NAME" >/dev/null 2>&1 || die "no such user: $USER_NAME"
HOME_DIR=$(getent passwd "$USER_NAME" | cut -d: -f6)
echo "profile=$PROFILE user=$USER_NAME home=$HOME_DIR theme=$THEME aur=$AUR"

# ---------------------------------------------------------------- packages
step "pacman packages"
lists="base desktop"; [ "$PROFILE" = headless-vnc ] && lists="$lists headless-vnc"
wanted=(); for l in $lists; do mapfile -t -O "${#wanted[@]}" wanted < <(pkgs "$l"); done
pacman -Syu --needed --noconfirm "${wanted[@]}"

# AUR without a helper: clone, install repo deps as root, build as the user,
# install the result. No sudo prompts mid-build and one less tool to trust.
aur_install() {
  local p="$1" dir deps
  pacman -Q "$p" >/dev/null 2>&1 && { note "$p already installed"; return; }
  dir=$(as_user mktemp -d)
  as_user git clone -q "https://aur.archlinux.org/$p.git" "$dir/$p"
  deps=$(as_user sh -c "cd '$dir/$p' && makepkg --printsrcinfo" \
         | awk -F' = ' '/^\t(make)?depends = /{sub(/[<>=].*/,"",$2); print $2}')
  [ -n "$deps" ] && pacman -S --needed --noconfirm $deps
  as_user sh -c "cd '$dir/$p' && makepkg --noconfirm --needed"
  pacman -U --noconfirm "$dir/$p"/*.pkg.tar.*
  rm -rf "$dir"
}
if [ "$AUR" = 1 ]; then
  step "AUR packages"
  while read -r p; do [ -n "$p" ] && aur_install "$p"; done < <(pkgs aur)
fi

# ---------------------------------------------------------------- user
step "user $USER_NAME"
[ "$PROFILE" = headless-vnc ] && usermod -aG render,video,seat "$USER_NAME"
[ "$(getent passwd "$USER_NAME" | cut -d: -f7)" = /usr/bin/zsh ] || chsh -s /usr/bin/zsh "$USER_NAME"
note "groups: $(id -nG "$USER_NAME")   shell: $(getent passwd "$USER_NAME" | cut -d: -f7)"

# ---------------------------------------------------------------- theme kit
step "labs-theme (Omarchy's themes + renderer, see theme/NOTICE)"
rsync -a --delete "$HERE/theme/" /usr/local/share/labs-theme/
for c in labs-theme-set labs-theme-pick labs-menu; do ln -sfn "/usr/local/share/labs-theme/bin/$c" "/usr/local/bin/$c"; done
note "$(ls /usr/local/share/labs-theme/themes | wc -l) themes installed"

# ---------------------------------------------------------------- deploy helpers
# render <src> <dst> <mode> <owner>: substitute @HOME@ @USER@ @TSIP@, back up a
# differing existing file once, install with the given mode/owner.
render() {
  local src="$1" dst="$2" mode="$3" owner="$4" tmp
  tmp=$(mktemp)
  sed -e "s#@HOME@#$HOME_DIR#g" -e "s#@USER@#$USER_NAME#g" -e "s#@TSIP@#${TSIP:-}#g" "$src" > "$tmp"
  if [ -f "$dst" ] && ! cmp -s "$tmp" "$dst" && [ ! -e "$dst.pre-labs" ]; then cp -p "$dst" "$dst.pre-labs"; note "backed up $dst -> $dst.pre-labs"; fi
  install -D -m "$mode" -o "${owner%%:*}" -g "${owner##*:}" "$tmp" "$dst"; rm -f "$tmp"
}

step "home files -> $HOME_DIR"
while IFS= read -r -d '' f; do
  rel="${f#"$HERE/files/home/"}"; mode=644; [ -x "$f" ] && mode=755
  render "$f" "$HOME_DIR/$rel" "$mode" "$USER_NAME:$USER_NAME"
  # parent dirs created by install -D are root-owned; hand them to the user
  d=$(dirname "$HOME_DIR/$rel"); while [ "$d" != "$HOME_DIR" ]; do chown "$USER_NAME:$USER_NAME" "$d"; d=$(dirname "$d"); done
  note "$rel"
done < <(find "$HERE/files/home" -type f -print0 | sort -z)

# ---------------------------------------------------------------- theme state
if [ ! -e "$HOME_DIR/.local/state/labs-theme/current/name" ]; then
  step "starting theme: $THEME"
  as_user labs-theme-set "$THEME"
else
  note "keeping current theme: $(cat "$HOME_DIR/.local/state/labs-theme/current/name")"
fi

# ---------------------------------------------------------------- headless-vnc
if [ "$PROFILE" = headless-vnc ]; then
  step "headless-vnc: virtual display + wayvnc on the tailnet"
  systemctl enable --now tailscaled >/dev/null
  TSIP=$(tailscale ip -4 2>/dev/null | sed -n 1p || true)
  if [ -z "$TSIP" ]; then
    note "NOT on the tailnet yet: run 'sudo tailscale up', then re-run this script."
    note "wayvnc binds to the tailnet IP only, so it is not set up until then."
  else
    note "tailnet IP: $TSIP"
    S="$HERE/files/system/headless-vnc"
    render "$S/etc/systemd/system/hyprland-headless.service" /etc/systemd/system/hyprland-headless.service 644 root:root
    render "$S/etc/systemd/system/wayvnc.service"            /etc/systemd/system/wayvnc.service            644 root:root
    render "$S/etc/tmpfiles.d/labs-vnc.conf"                 /etc/tmpfiles.d/labs-vnc.conf                 644 root:root
    install -m 755 "$S/usr/local/bin/wait-for-tailscale-ip.sh" /usr/local/bin/wait-for-tailscale-ip.sh

    cfg="$HOME_DIR/.config/wayvnc/config"
    if [ -f "$cfg" ] && grep -q '^password=' "$cfg"; then
      sed -i "s#^address=.*#address=$TSIP#" "$cfg"; note "kept existing wayvnc password; address -> $TSIP"
    else
      [ -r /dev/tty ] || die "no terminal to prompt for the wayvnc password"
      read -rsp "   wayvnc password (only the first 8 characters count): " pw </dev/tty; echo
      [ -n "$pw" ] || die "empty password"
      install -d -m 700 -o "$USER_NAME" -g "$USER_NAME" "$HOME_DIR/.config/wayvnc"
      # ENVIRON + index/substr: a password with & or \ must pass through literally
      sed -e "s#@TSIP@#$TSIP#" "$S/wayvnc-config.tmpl" | PW="$pw" awk '{i=index($0,"@PASSWORD@"); if(i) $0=substr($0,1,i-1) ENVIRON["PW"] substr($0,i+10)}1' \
        | install -m 600 -o "$USER_NAME" -g "$USER_NAME" /dev/stdin "$cfg"
      unset pw
    fi

    systemd-tmpfiles --create /etc/tmpfiles.d/labs-vnc.conf
    systemctl daemon-reload
    systemctl enable --now seatd >/dev/null
    systemctl enable hyprland-headless wayvnc >/dev/null
    systemctl restart hyprland-headless; sleep 5; systemctl restart wayvnc
    if ufw status 2>/dev/null | grep '^Status: active' >/dev/null; then   # no -q: -q can SIGPIPE ufw under pipefail
      ufw allow in on tailscale0 to any port 5900 proto tcp comment 'wayvnc, tailnet only' >/dev/null
      note "ufw: 5900/tcp allowed on tailscale0 only"
    else
      note "ufw is inactive; wayvnc is still bound to $TSIP only"
    fi
    note "hyprland-headless: $(systemctl is-active hyprland-headless)  wayvnc: $(systemctl is-active wayvnc)"
  fi
fi

step "done"
[ "$PROFILE" = headless-vnc ] && [ -n "${TSIP:-}" ] && note "VNC: $TSIP:5900"
note "theme picker: Super+Ctrl+Shift+Space (VNC-safe: Ctrl+Alt+P)   menu: Super+Alt+Space (Ctrl+Alt+M)"
note "or from a shell: labs-theme-set <name>   ($(ls /usr/local/share/labs-theme/themes | tr '\n' ' '))"
