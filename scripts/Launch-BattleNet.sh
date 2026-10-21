#!/bin/bash
# Battle.net Steam shortcut: gamescope stamper + Proton (tier-8 compat tool).
#
# Steam: .exe target, launch options /usr/local/bin/Launch-BattleNet.sh %command%
# Optional env: /usr/local/etc/wow-forever.env (BNET_DIR, WOW_ROOT, FEX_*, WOW_LOGDIR)
set -uo pipefail

ENV_FILE="${WOW_ENV:-/usr/local/etc/wow-forever.env}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

APPID="${SteamAppId:-${SteamGameId:-${BNET_APPID:-}}}"
if [[ "$APPID" == "0" || -z "$APPID" || ${#APPID} -gt 10 ]]; then
  APPID="${BNET_APPID:-}"
fi
if [[ -z "$APPID" ]]; then
  echo "Launch-BattleNet: launch from Steam or set BNET_APPID" >&2
  exit 1
fi

STAMPER="${WOW_STAMPER:-$(command -v droiddeck-steamgame-stamp.sh 2>/dev/null || echo /usr/local/bin/droiddeck-steamgame-stamp.sh)}"
DPY="${DISPLAY:-${STEAM_DISPLAY:-:1}}"
if [[ -x "$STAMPER" ]]; then
  "$STAMPER" "$APPID" $$ "$DPY" &
else
  echo "Launch-BattleNet: warning: no stamper at $STAMPER" >&2
fi

STEAM_ROOT="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-${WOW_STEAM_ROOT:-${HOME:-/root}/.local/share/Steam}}"
PREFIX="${STEAM_COMPAT_DATA_PATH:-${WOW_PREFIX:-}}"
if [[ -z "$PREFIX" ]]; then
  PREFIX="$STEAM_ROOT/steamapps/compatdata/$APPID"
fi

find_bnet() {
  local d
  if [[ -n "${BNET_DIR:-}" && -f "${BNET_DIR}/Battle.net Launcher.exe" ]]; then
    printf '%s\n' "$BNET_DIR"
    return 0
  fi
  for d in /root/Storage/Battle.net \
           "$PREFIX/pfx/drive_c/Program Files (x86)/Battle.net" \
           "$PREFIX/pfx/drive_c/Program Files/Battle.net"; do
    if [[ -f "$d/Battle.net Launcher.exe" ]]; then
      printf '%s\n' "$d"
      return 0
    fi
  done
  return 1
}

find_tool() {
  local p
  if [[ -n "${STEAM_COMPAT_TOOL_PATHS:-}" ]]; then
    p="${STEAM_COMPAT_TOOL_PATHS%%:*}"
    if [[ -x "$p/droiddeck-proton-wrap" ]]; then
      printf '%s\n' "$p"
      return 0
    fi
  fi
  if [[ -n "${WOW_PROTON_DIR:-}" && -x "${WOW_PROTON_DIR}/droiddeck-proton-wrap" ]]; then
    printf '%s\n' "$WOW_PROTON_DIR"
    return 0
  fi
  return 1
}

BNET="$(find_bnet)" || { echo "Launch-BattleNet: Battle.net Launcher.exe not found (set BNET_DIR)" >&2; exit 1; }
EXE="$BNET/Battle.net Launcher.exe"
LOGDIR="${WOW_LOGDIR:-/tmp/wow-launch-$APPID}"
LOG="$LOGDIR/bnet-launch.log"

TOOL="$(find_tool)" || {
  echo "Launch-BattleNet: set Compatibility tool on this shortcut in Steam (DroidDeck)" >&2
  exit 1
}
PROTON="$TOOL/droiddeck-proton-wrap"

ICD="${VK_ICD_FILENAMES:-${VK_DRIVER_FILES:-${BL_VK_DRIVER:-}}}"
ICD="${ICD%%:*}"

mkdir -p "$LOGDIR"
exec >>"$LOG" 2>&1
echo "======== $(date -Iseconds) pid=$$ ========"
echo "appid=$APPID prefix=$PREFIX tool=$TOOL bnet=$BNET stamper=$STAMPER"
echo "session-icd=$ICD steam_compat_data=${STEAM_COMPAT_DATA_PATH:-unset}"

for f in "$PROTON" "$EXE"; do
  if [[ ! -e "$f" ]]; then echo "Launch-BattleNet: missing $f"; exit 1; fi
done
if [[ -z "$ICD" || ! -r "$ICD" ]]; then
  echo "Launch-BattleNet: no session Vulkan ICD (pick a driver in DroidDeck)"
  exit 1
fi

export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_ROOT"
export STEAM_COMPAT_DATA_PATH="$PREFIX"
export SteamAppId="$APPID"
export SteamGameId="${SteamGameId:-$APPID}"
if [[ -z "${VK_ICD_FILENAMES:-}" && -z "${VK_DRIVER_FILES:-}" ]]; then
  export VK_ICD_FILENAMES="$ICD"
  export VK_DRIVER_FILES="$ICD"
fi

pre="${LD_PRELOAD:-}"
pre="${pre//\/root\/.steam\/bin32\/gameoverlayrenderer.so/}"
pre="${pre##:}"; pre="${pre%%:}"
export LD_PRELOAD="${pre:-}"

if [[ -n "${FEX_APP_DATA_LOCATION:-}" ]]; then
  mkdir -p "$FEX_APP_DATA_LOCATION"
  export FEX_APP_DATA_LOCATION
fi
[[ -n "${FEX_BNET_FORCE_X86:-}" ]] && export FEX_BNET_FORCE_X86
[[ -n "${FEX_DYNAMICL1CACHE:-}" ]] && export FEX_DYNAMICL1CACHE

WOW_ROOT="${WOW_ROOT:-}"
if [[ -n "$WOW_ROOT" && -d "$WOW_ROOT" ]]; then
  PF86="$PREFIX/pfx/drive_c/Program Files (x86)"
  if [[ -d "$PF86" && ! -e "$PF86/World of Warcraft" ]]; then
    ln -s "$WOW_ROOT" "$PF86/World of Warcraft"
    echo "linked Program Files (x86)/World of Warcraft -> $WOW_ROOT"
  fi
fi

cd "$BNET" || exit 1
echo "exec proton waitforexitandrun $EXE"
"$PROTON" waitforexitandrun "$EXE"
rc=$?
echo "proton-exit $rc"
exit "$rc"
