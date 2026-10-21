#!/usr/bin/env python3
import argparse
import json
import urllib.request

BASE = "http://127.0.0.1:18765"

def request(command):
    if command == "ping":
        req = urllib.request.Request(BASE + "/ping", method="GET")
    elif command == "status":
        req = urllib.request.Request(BASE + "/status", method="GET")
    else:
        req = urllib.request.Request(BASE + "/clear", method="POST")
    with urllib.request.urlopen(req, timeout=5) as response:
        return response.read().decode("utf-8", errors="replace")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("command", choices=["ping", "status", "clear"])
    args = parser.parse_args()
    result = request(args.command)
    try:
        print(json.dumps(json.loads(result), ensure_ascii=False, indent=2))
    except Exception:
        print(result)

if __name__ == "__main__":
    main()
