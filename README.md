# Arch

A fresh Arch install becomes one of my machines with one command. Packages, the
Hyprland desktop, an Omarchy-style waybar, Omarchy's 22 themes with a live theme
picker, the zsh profile, and (optionally) a headless desktop reached over VNC on the
tailnet. Nothing depends on an Omarchy machine to copy from.

## Install
1. Install Arch (e.g. `archinstall`), with a user in `wheel` who can `sudo`.
2. For the default `headless-vnc` profile, join the tailnet first:
   `sudo pacman -S tailscale && sudo systemctl enable --now tailscaled && sudo tailscale up`.
   (You can do it afterwards and re-run step 3; the VNC part waits for it.)
3. As your user (it asks for your sudo password) or as root on a minimal box:
   ```sh
   curl -fsSL https://raw.githubusercontent.com/cbaugus/Arch/main/install.sh | bash
   ```
   For a machine with a real screen:
   ```sh
   curl -fsSL https://raw.githubusercontent.com/cbaugus/Arch/main/install.sh | bash -s -- --profile desktop
   ```

`install.sh` elevates with sudo if needed, installs git, clones this repo into
`/usr/local/src/cbaugus-arch` (or updates it) and runs `setup.sh`, which does the
work. From a clone, `./install.sh [options]` uses that clone as it is.
Run as root, it sets up the only regular user; if there are none or several, create
one (`useradd -m -G wheel NAME && passwd NAME`) or pass `--user NAME`.

The script prompts once, for the wayvnc password, which is never stored in the repo.
Re-running it is safe and is how you pick up changes: packages are `--needed`, a
changed file is backed up once as `<file>.pre-labs`, and the existing theme and
password are kept. Secrets for your shell go in `~/.zshrc.local`, which is never
touched.

## Profiles
| | |
|---|---|
| `headless-vnc` (default) | Hyprland on a virtual 1920x1080 display, reached **only over the tailnet** with wayvnc (`<tailnet-ip>:5900`). For machines with no monitor. |
| `desktop` | Packages, bar, themes and shell only; no VNC services. |

Options (after `bash -s --`): `--user NAME`, `--theme NAME` (default `tokyo-night`), `--no-aur`.

## What it sets up
- **Packages**: `packages/{base,desktop,headless-vnc}.txt` from pacman, and
  `packages/aur.txt` from the AUR. AUR packages are built without a helper: clone,
  install repo deps as root, build as the user, `pacman -U`. There's no yay and
  no sudo prompts mid-build.
- **Shell**: zsh with starship, zoxide, fzf, autosuggestions and syntax
  highlighting (`files/home/.zshrc`).
- **Bar**: an Omarchy-style waybar (`files/home/.config/waybar/`). It has the menu,
  workspaces, idle and do-not-disturb indicators, clock, weather, pending
  updates, tray, bluetooth, network, audio and power.
- **Themes**: `theme/`, Omarchy's theme system rebuilt for plain Arch, using its
  22 themes, renderer and templates (MIT, see `theme/NOTICE`). One command
  re-colours the bar, window borders, notifications, launcher, foot, kitty and
  wallpaper live.
  - Picker: **Super+Ctrl+Shift+Space** (VNC-safe **Ctrl+Alt+P**)
  - Menu: **Super+Alt+Space** (**Ctrl+Alt+M**)
  - Launcher: **Super+Space** (**Ctrl+Alt+Space**)
  - Shell: `labs-theme-set <name>`
  - Your own themes go in `~/.config/labs-theme/themes/<name>/` (a
    `colors.toml` plus `backgrounds/`), and your own templates in
    `~/.config/labs-theme/themed/`.
- **headless-vnc**: `seatd`, a `hyprland-headless` service using its own
  `~/.config/hypr-headless/`, so it never touches a real desktop session's
  `~/.config/hypr`. Also a `wayvnc` service bound to the tailnet IP only,
  with ufw allowing 5900 on `tailscale0` only.

## Adding to it
- A package goes in the right `packages/*.txt`.
- A dotfile goes under `files/home/` at the path it has in `$HOME`. `@HOME@`,
  `@USER@` and `@TSIP@` are substituted when it's deployed.
- A system file for a profile goes under `files/system/<profile>/`.
- Commit, push, and re-run the curl line (or `./install.sh`) on each machine.

## Verified
tower1, 2026-09-25: a full run on a freshly reinstalled machine covered pacman,
google-chrome from the AUR, the theme kit, configs, and the virtual display plus
wayvnc (handshake OK over the tailnet). A second run was a no-op, and live theme
switching was verified. The same day, the curl one-liner was run as root with no
options: it picked the only regular user and finished with the services active.
