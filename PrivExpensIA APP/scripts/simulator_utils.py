#!/usr/bin/env python3
import argparse
import json
import subprocess
import sys
from typing import List, Dict, Optional


def run(cmd: List[str]) -> subprocess.CompletedProcess:
    return subprocess.run(cmd, capture_output=True, text=True)


def list_devices_json() -> Dict:
    proc = run(["xcrun", "simctl", "list", "devices", "--json"])
    if proc.returncode != 0:
        print(proc.stderr.strip(), file=sys.stderr)
        return {"devices": {}}
    try:
        return json.loads(proc.stdout)
    except json.JSONDecodeError:
        return {"devices": {}}


def find_device_udid_by_name(name: str, prefer_available: bool = True) -> Optional[str]:
    data = list_devices_json()
    for runtime, devs in data.get("devices", {}).items():
        if "iOS" not in runtime:
            continue
        for d in devs:
            if d.get("name") == name and (not prefer_available or d.get("isAvailable")):
                return d.get("udid")
    return None


def ensure_booted(udid: str) -> bool:
    # Boot if needed; ignore errors if already booted
    subprocess.run(["xcrun", "simctl", "boot", udid], capture_output=True)
    # Wait until fully booted
    wait = subprocess.run(["xcrun", "simctl", "bootstatus", udid, "-b"], capture_output=True, text=True)
    return wait.returncode == 0


def ensure_simulator_running_by_name(name: str) -> Optional[str]:
    udid = find_device_udid_by_name(name)
    if not udid:
        # Try to create the device if missing (fallback to latest available runtime/device type heuristics)
        # This is best-effort; we do not guess runtime here.
        return None
    ensure_booted(udid)
    return udid


def list_booted_simulators() -> List[Dict[str, str]]:
    data = list_devices_json()
    result: List[Dict[str, str]] = []
    for runtime, devs in data.get("devices", {}).items():
        if "iOS" not in runtime:
            continue
        for d in devs:
            if d.get("isAvailable") and d.get("state") == "Booted":
                result.append({"name": d.get("name", ""), "udid": d.get("udid", ""), "state": d.get("state", "")})
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description="Simulator utilities")
    parser.add_argument("--ensure", action="store_true", help="Ensure simulator is booted (with --name)")
    parser.add_argument("--name", type=str, default="", help="Simulator device name, e.g. 'iPhone 16 Pro Max'")
    parser.add_argument("--list-booted", action="store_true", help="List booted simulators as JSON")
    args = parser.parse_args()

    if args.list_booted:
        print(json.dumps(list_booted_simulators(), ensure_ascii=False))
        return 0

    if args.ensure and args.name:
        udid = ensure_simulator_running_by_name(args.name)
        if not udid:
            print("", end="")
            return 1
        print(udid)
        return 0

    if args.name:
        udid = find_device_udid_by_name(args.name)
        if not udid:
            print("", end="")
            return 1
        print(udid)
        return 0

    # Default: print nothing
    print("", end="")
    return 0


if __name__ == "__main__":
    sys.exit(main())


