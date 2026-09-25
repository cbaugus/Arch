#!/bin/bash
# wait-for-tailscale-ip.sh <ip> [timeout-seconds]
#
# Blocks until the given IPv4 address is present on a local interface.
# Used as an ExecStartPre for services (wayvnc.service) that must bind
# to a Tailscale address: tailscaled.service being "active" does not
# mean the tailnet IP is assigned yet, particularly right after boot
# while tailscaled is still reconnecting to the control plane. Exits
# non-zero on timeout, which fails the ExecStartPre and lets systemd's
# Restart= handling retry the whole unit.
set -euo pipefail

ip_addr="${1:?usage: wait-for-tailscale-ip.sh <ip> [timeout-seconds]}"
timeout="${2:-60}"
waited=0

while ! ip -4 addr show 2>/dev/null | grep -q "inet ${ip_addr}/"; do
    if [ "$waited" -ge "$timeout" ]; then
        echo "wait-for-tailscale-ip: ${ip_addr} not present after ${timeout}s" >&2
        exit 1
    fi
    sleep 1
    waited=$((waited + 1))
done

exit 0
