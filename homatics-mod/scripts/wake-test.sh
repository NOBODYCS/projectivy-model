#!/usr/bin/env bash
# Power the box "off" via remote power key (press it now), then test reachability.
set -euo pipefail
source "$(dirname "$0")/common.sh"
echo "Press the POWER button on the remote now. Waiting 20s..."
sleep 20
IP="${BOX_IP:-$(adb_cmd shell ip route | awk '{print $9}' | head -1 | tr -d '\r')}"
echo "pinging $IP ..."
if ping -c 4 -W 2 "$IP" >/dev/null 2>&1; then
  echo "REACHABLE in standby — HA power-on likely works."
else
  echo "NOT reachable — box drops network in standby. Use Ethernet; test adb connect $IP:5555 after wake."
fi
