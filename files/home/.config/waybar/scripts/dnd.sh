#!/usr/bin/env bash
# Do-not-disturb indicator (mako mode). Shown only while DND is on, like Omarchy's indicator.
if makoctl mode 2>/dev/null | grep -qx do-not-disturb; then
  echo '{"text":"\U000f009b","tooltip":"Do not disturb (click to turn off)","class":"on"}'
else echo '{"text":""}'; fi
