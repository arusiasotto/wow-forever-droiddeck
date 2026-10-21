#!/bin/bash
set -euo pipefail
SERIAL="${ADB_SERIAL:-912601210098}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
URI="content://com.droiddeck.launcher.agent"
guest() {
  local cmd="$1" timeout="${2:-120}"
  local req
  req="$(python3 -c 'import json,base64,sys; print(base64.b64encode(json.dumps({"argv":["bash","-lc",sys.stdin.read()],"timeout":int(sys.argv[1])}).encode()).decode())' "$timeout" <<< "$cmd")"
  adb -s "$SERIAL" shell content call --uri "$URI" --method guest --extra "request:s:$req"
}
b64="$(base64 -w0 "$ROOT/scripts/rename-proton-wow-tool.sh")"
guest "echo '$b64' | base64 -d > /tmp/rename-proton-wow-tool.sh && chmod 755 /tmp/rename-proton-wow-tool.sh && /tmp/rename-proton-wow-tool.sh"
