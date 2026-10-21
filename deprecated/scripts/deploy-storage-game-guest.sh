#!/bin/bash
# Push Storage/Game WoW launch path to DroidDeck guest. Does not change Battle.net scripts/env.
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

echo "Deploy Storage/Game WoW launch to guest $SERIAL …"
push_file "$ROOT/scripts/Launch-WoW-Storage.sh" /usr/local/bin/Launch-WoW-Storage.sh
push_file "$ROOT/scripts/Launch-WoW.sh" /usr/local/bin/Launch-WoW.sh
push_file "$ROOT/scripts/droiddeck-steamgame-stamp.sh" /usr/local/bin/droiddeck-steamgame-stamp.sh
push_file "$ROOT/scripts/droiddeck-steam-stamper-wrap.sh" /usr/local/bin/droiddeck-steam-stamper-wrap.sh
push_file "$ROOT/scripts/wow-forever-storage.env" /usr/local/etc/wow-forever-storage.env 0644
push_file "$ROOT/scripts/wow-forever-storage.env.example" /usr/local/etc/wow-forever-storage.env.example 0644
push_file "$ROOT/scripts/restore-working-shortcut.py" /usr/local/bin/restore-working-shortcut.py 0755

push_file "$ROOT/scripts/fix-wow-launch-options.py" /usr/local/bin/fix-wow-launch-options.py 0755
guest "/usr/local/bin/restore-working-shortcut.py && /usr/local/bin/fix-wow-launch-options.py"

guest "echo '=== wow-forever-storage.env ==='; cat /usr/local/etc/wow-forever-storage.env; echo; ls -la /usr/local/bin/Launch-WoW-Storage.sh /root/Storage/Game/_classic_beta_/WowB-ARM64.exe"

echo "Done. Battle.net launcher untouched; WoW tile uses Launch-WoW.sh + /root/Storage/Game."
