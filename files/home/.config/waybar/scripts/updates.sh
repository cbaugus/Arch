#!/usr/bin/env bash
# Pending pacman updates (checkupdates, from pacman-contrib). Empty text when none -> module hides.
n=$(checkupdates 2>/dev/null | wc -l)
if [ "$n" -gt 0 ]; then
  jq -cn --arg n "$n" '{text:("\U000f06b0 "+$n), tooltip:($n+" updates available (click to update)"), class:"pending"}'
else echo '{"text":""}'; fi
