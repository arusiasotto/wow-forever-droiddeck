#!/bin/bash
# Prepend to Steam Launch Options so gamescope gets STEAM_GAME / focus on Proton windows.
# Same PID survives exec(), so the stamper runs until the game (or Proton) exits.
#
# Battle.net shortcut example:
#   /usr/local/bin/droiddeck-steam-stamper-wrap.sh %command%
#
# With a helper before the game exe:
#   /usr/local/bin/droiddeck-steam-stamper-wrap.sh /usr/local/bin/Launch-BattleNet.sh %command%
#
# Optional: STEAM_STAMPER_APPID if SteamAppId is unset (manual testing).
set -u

APPID="${SteamAppId:-${SteamGameId:-${STEAM_STAMPER_APPID:-${BNET_APPID:-}}}}"
if [[ "$APPID" == "0" || -z "$APPID" || ${#APPID} -gt 10 ]]; then
  APPID="${STEAM_STAMPER_APPID:-${BNET_APPID:-}}"
fi
if [[ -z "$APPID" ]]; then
  echo "droiddeck-steam-stamper-wrap: launch from Steam or set STEAM_STAMPER_APPID" >&2
  exit 1
fi

STAMPER="${WOW_STAMPER:-$(command -v droiddeck-steamgame-stamp.sh 2>/dev/null || echo /usr/local/bin/droiddeck-steamgame-stamp.sh)}"
DPY="${DISPLAY:-${STEAM_DISPLAY:-:1}}"

if [[ -x "$STAMPER" ]]; then
  "$STAMPER" "$APPID" $$ "$DPY" &
else
  echo "droiddeck-steam-stamper-wrap: warning: no stamper at $STAMPER" >&2
fi

if [[ $# -eq 0 ]]; then
  echo "droiddeck-steam-stamper-wrap: nothing to exec (check Launch Options / %command%)" >&2
  exit 1
fi
exec "$@"
