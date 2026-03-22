#!/bin/bash

set -euo pipefail

# Usage: 01_boot_sim.sh [--udid <UDID> | --name "iPhone 16 Pro Max"]

UDID=""
NAME=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --udid) UDID="$2"; shift 2;;
    --name) NAME="$2"; shift 2;;
    *) shift;;
  esac
done

resolve_udid_by_name() {
  local name="$1"
  xcrun simctl list devices | grep -F "$name" | grep -v unavailable |
    grep -E -o '[A-F0-9-]{36}' | head -n1 || true
}

if [[ -z "$UDID" && -n "$NAME" ]]; then
  UDID=$(resolve_udid_by_name "$NAME")
fi

if [[ -z "$UDID" ]]; then
  echo "❌ Fournir --udid ou --name" >&2
  exit 1
fi

echo "📱 Boot du simulateur $UDID ..."
xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
xcrun simctl boot "$UDID" >/dev/null 2>&1 || true
xcrun simctl bootstatus "$UDID" -b
open -a Simulator --args -CurrentDeviceUDID "$UDID"
echo "✅ Simulateur prêt: $UDID"


