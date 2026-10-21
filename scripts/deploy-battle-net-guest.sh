#!/bin/bash
# Push peeled Battle.net launch path to DroidDeck guest.
set -euo pipefail

SERIAL="${ADB_SERIAL:-912601210098}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
URI="content://com.droiddeck.launcher.agent"

guest() {
  local cmd="$1"
  local timeout="${2:-180}"
  local req
  req="$(python3 -c 'import json,base64,sys; print(base64.b64encode(json.dumps({"argv":["bash","-lc",sys.stdin.read()],"timeout":int(sys.argv[1])}).encode()).decode())' "$timeout" <<< "$cmd")"
  adb -s "$SERIAL" shell content call --uri "$URI" --method guest --extra "request:s:$req"
}

push_file() {
  local src="$1" dest="$2" mode="${3:-0755}"
  local b64
  b64="$(base64 -w0 "$src")"
  guest "echo '$b64' | base64 -d > '${dest}.tmp' && mv -f '${dest}.tmp' '$dest' && chmod $mode '$dest' && echo pushed $dest"
}

echo "Deploy peeled Battle.net launch to guest $SERIAL …"
push_file "$ROOT/scripts/droiddeck-steam-stamper-wrap.sh" /usr/local/bin/droiddeck-steam-stamper-wrap.sh
push_file "$ROOT/scripts/droiddeck-steamgame-stamp.sh" /usr/local/bin/droiddeck-steamgame-stamp.sh
push_file "$ROOT/scripts/Launch-BattleNet.sh" /usr/local/bin/Launch-BattleNet.sh
push_file "$ROOT/scripts/Launch-BattleNet-Proton.sh" /usr/local/bin/Launch-BattleNet-Proton.sh
push_file "$ROOT/scripts/wow-forever.env.example" /usr/local/etc/wow-forever.env.example 0644
if [[ -f "$ROOT/scripts/wow-forever.env" ]]; then
  push_file "$ROOT/scripts/wow-forever.env" /usr/local/etc/wow-forever.env 0644
else
  guest "install -d /usr/local/etc; cp -f /usr/local/etc/wow-forever.env.example /usr/local/etc/wow-forever.env"
fi

guest "head -5 /usr/local/etc/wow-forever.env 2>/dev/null; echo; head -3 /usr/local/bin/Launch-BattleNet.sh"

echo "Done. See README: Proton … ARM64EC WoW, Launch-BattleNet.sh %command%, -d3d11 in Battle.net."
