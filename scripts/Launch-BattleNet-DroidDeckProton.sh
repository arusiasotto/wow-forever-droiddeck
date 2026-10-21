#!/bin/bash
# LEGACY: shim + ntdll sync + inline stamper. Prefer Launch-BattleNet-Proton.sh (tier 8).
# Battle.net under DroidDeck-Proton (x86 via FEX) in its own prefix.
# GPU ICD, esync, locale and Proton version come from the DroidDeck session.
# Play from here starts WowB in this prefix; closing Battle.net also kills it.
set -uo pipefail

ENV_FILE="${WOW_ENV:-/usr/local/etc/wow-forever.env}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

APPID="${SteamAppId:-${BNET_APPID:-4153382437}}"
if [[ "$APPID" == "0" || ${#APPID} -gt 10 ]]; then APPID="${BNET_APPID:-4153382437}"; fi
STEAM_ROOT="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-/root/.local/share/Steam}"
PREFIX="${STEAM_COMPAT_DATA_PATH:-$STEAM_ROOT/steamapps/compatdata/$APPID}"
SHIM="${WOW_SIGSHIM:-/usr/local/lib/libsigctx_zero.so}"
TEBSTUB_OFFSETS="${WOW_TEBSTUB_OFFSETS:-b0a68:43240}"
WOW_ROOT="${WOW_ROOT:-/root/Storage/Game}"

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

BNET="$(find_bnet)" || { echo "Launch-BattleNet: Battle.net Launcher.exe not found (set BNET_DIR)" >&2; exit 1; }
EXE="$BNET/Battle.net Launcher.exe"
LOGDIR="${WOW_LOGDIR:-/tmp/wow-launch}"
LOG="$LOGDIR/bnet-launch.log"
STAMPER="${WOW_STAMPER:-/usr/local/bin/droiddeck-steamgame-stamp.sh}"

find_tool() {
  local d p
  if [[ -n "${WOW_PROTON_DIR:-}" && -x "${WOW_PROTON_DIR}/droiddeck-proton-wrap" ]]; then
    printf '%s\n' "$WOW_PROTON_DIR"
    return 0
  fi
  if [[ -n "${STEAM_COMPAT_TOOL_PATHS:-}" ]]; then
    p="${STEAM_COMPAT_TOOL_PATHS%%:*}"
    if [[ -x "$p/droiddeck-proton-wrap" ]]; then
      printf '%s\n' "$p"
      return 0
    fi
  fi
  for d in "$STEAM_ROOT/compatibilitytools.d"/DroidDeck-Proton*; do
    if [[ -x "$d/droiddeck-proton-wrap" ]]; then
      printf '%s\n' "$d"
      return 0
    fi
  done
  return 1
}

TOOL="$(find_tool)" || { echo "Launch-BattleNet: no DroidDeck-Proton wrap" >&2; exit 1; }
PROTON="$TOOL/droiddeck-proton-wrap"
NTDLL_SRC="$TOOL/files/lib/wine/aarch64-windows/ntdll.dll"
ICD="${VK_ICD_FILENAMES:-${VK_DRIVER_FILES:-${BL_VK_DRIVER:-}}}"
ICD="${ICD%%:*}"

mkdir -p "$LOGDIR"
exec >>"$LOG" 2>&1
echo "======== $(date -Iseconds) pid=$$ ========"
echo "appid=$APPID prefix=$PREFIX tool=$TOOL"
echo "session-icd=$ICD"

for f in "$PROTON" "$SHIM" "$EXE" "$NTDLL_SRC"; do
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
export WINE_TEBSTUB_OFFSETS="$TEBSTUB_OFFSETS"
export FEX_APP_DATA_LOCATION="${FEX_APP_DATA_LOCATION:-/run/droiddeck/fex-$APPID/}"
mkdir -p "$FEX_APP_DATA_LOCATION"
export FEX_BNET_FORCE_X86="${FEX_BNET_FORCE_X86:-1}"
export FEX_DYNAMICL1CACHE="${FEX_DYNAMICL1CACHE:-0}"

pre="${LD_PRELOAD:-}"
pre="${pre//\/root\/.steam\/bin32\/gameoverlayrenderer.so/}"
pre="${pre##:}"; pre="${pre%%:}"
export LD_PRELOAD="${pre:+$pre:}$SHIM"
echo "LD_PRELOAD=$LD_PRELOAD WINE_TEBSTUB_OFFSETS=$WINE_TEBSTUB_OFFSETS VK_ICD_FILENAMES=${VK_ICD_FILENAMES:-}"

PF86="$PREFIX/pfx/drive_c/Program Files (x86)"
if [[ -d "$PF86" && ! -e "$PF86/World of Warcraft" && -d "$WOW_ROOT" ]]; then
  ln -s "$WOW_ROOT" "$PF86/World of Warcraft"
  echo "linked Program Files (x86)/World of Warcraft -> $WOW_ROOT"
fi

SYS32="$PREFIX/pfx/drive_c/windows/system32"
if [[ -f "$SYS32/ntdll.dll" ]] && ! cmp -s "$NTDLL_SRC" "$SYS32/ntdll.dll"; then
  cp -f "$NTDLL_SRC" "$SYS32/ntdll.dll.bl-new" && mv -f "$SYS32/ntdll.dll.bl-new" "$SYS32/ntdll.dll"
  echo "synced patched ntdll.dll into prefix"
fi

if [[ -z "${BNET_NO_STAMPER:-${WOW_NO_STAMPER:-}}" && -x "$STAMPER" ]]; then
  "$STAMPER" "$APPID" $$ "${DISPLAY:-:1}" >>"$LOGDIR/stamper.log" 2>&1 &
  echo "stamper pid $!"
fi

cd "$BNET" || exit 1
echo "exec proton waitforexitandrun $EXE"
"$PROTON" waitforexitandrun "$EXE"
rc=$?
echo "proton-exit $rc"
if [[ -f "$SYS32/ntdll.dll" ]] && ! cmp -s "$NTDLL_SRC" "$SYS32/ntdll.dll"; then
  cp -f "$NTDLL_SRC" "$SYS32/ntdll.dll.bl-new" && mv -f "$SYS32/ntdll.dll.bl-new" "$SYS32/ntdll.dll"
  echo "re-synced ntdll.dll after exit"
fi
exit "$rc"
