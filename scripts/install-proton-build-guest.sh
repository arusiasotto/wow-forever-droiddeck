#!/bin/bash
# Install a DroidDeck-Proton zip/tar.gz onto the guest Steam compatibilitytools.d.
set -euo pipefail

SERIAL="${ADB_SERIAL:-912601210098}"
ZIP="${1:?usage: $0 /path/to/DroidDeck-Proton-....zip}"
URI="content://com.droiddeck.launcher.agent"

guest() {
  local cmd="$1"
  local timeout="${2:-600}"
  local req
  req="$(python3 -c 'import json,base64,sys; print(base64.b64encode(json.dumps({"argv":["bash","-lc",sys.stdin.read()],"timeout":int(sys.argv[1])}).encode()).decode())' "$timeout" <<< "$cmd")"
  adb -s "$SERIAL" shell content call --uri "$URI" --method guest --extra "request:s:$req"
}

BAS="$(basename "$ZIP")"
echo "Pushing $BAS to device Download …"
adb -s "$SERIAL" push "$ZIP" "/sdcard/Download/$BAS"

guest "
set -euo pipefail
ZIP='/sdcard/Download/$BAS'
for p in \"\$ZIP\" /mnt/user/0/emulated/0/Download/$BAS /root/Storage/Download/$BAS; do
  if [[ -f \"\$p\" ]]; then ZIP=\"\$p\"; break; fi
done
[[ -f \"\$ZIP\" ]] || { echo 'zip not visible in guest:'; ls -la /sdcard/Download/ 2>&1 || true; exit 1; }

STEAM=/root/.local/share/Steam
TOOLS=\"\$STEAM/compatibilitytools.d\"
WORK=/tmp/proton-install-\$\$
mkdir -p \"\$WORK\" \"\$TOOLS\"
cd \"\$WORK\"
echo using zip=\$ZIP
unzip -q \"\$ZIP\"
TAR=\$(ls -1 DroidDeck-Proton*.tar.gz | head -1)
echo extracting \"\$TAR\" into compatibilitytools.d
tar -xzf \"\$TAR\" -C \"\$TOOLS\"
DIR=\$(ls -1d \"\$TOOLS\"/DroidDeck-Proton*ARM64EC*WoW* 2>/dev/null | head -1)
if [[ -z \"\$DIR\" ]]; then
  echo 'No WoW-tagged Proton in compatibilitytools.d (expected *ARM64EC*WoW*)' >&2
  ls -1d \"\$TOOLS\"/DroidDeck-Proton* 2>/dev/null || true
  exit 1
fi
[[ -x \"\$DIR/droiddeck-proton-wrap\" || -x \"\$DIR/proton\" ]] || { echo 'bad tool dir' \"\$DIR\"; ls -la \"\$DIR\" | head; exit 1; }
echo INSTALLED=\"\$DIR\"
\"\$DIR/droiddeck-proton-wrap\" --version 2>/dev/null || cat \"\$DIR/version\" 2>/dev/null || true
rm -rf \"\$WORK\"
" 600

echo "Done."
