#!/usr/bin/env bash
# Power menu via wofi (Omarchy's power widget, rebuilt).
c=$(printf '%s\n' "  Logout" "  Suspend" "  Reboot" "  Shutdown" | wofi --dmenu --prompt Power --width 220 --lines 4 --hide-scroll) || exit 0
case "$c" in
  *Logout)   hyprctl dispatch 'hl.dsp.exit()' ;;
  *Suspend)  systemctl suspend ;;
  *Reboot)   systemctl reboot ;;
  *Shutdown) systemctl poweroff ;;
esac
