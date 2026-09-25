#!/usr/bin/env bash
# Weather for waybar (wttr.in, location from IP). Prints nothing -> module hides.
w=$(curl -sf --max-time 6 'https://wttr.in/?format=%c%t' 2>/dev/null | tr -s ' ') || exit 0
[ -z "$w" ] || [[ "$w" == *Unknown* ]] && exit 0
t=$(curl -sf --max-time 6 'https://wttr.in/?format=%l:+%C,+%t+(feels+%f),+wind+%w' 2>/dev/null)
jq -cn --arg text "$w" --arg tip "$t" '{text:$text, tooltip:$tip}'
