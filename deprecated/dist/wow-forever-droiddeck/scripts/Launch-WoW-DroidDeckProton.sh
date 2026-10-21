#!/bin/bash
# Direct WowB launch under DroidDeck-Proton in the Battle.net prefix.
# GPU ICD, esync, locale and Proton version come from the DroidDeck session.
# Never put d3d11/dxgi in WINEDLLOVERRIDES.
set -uo pipefail

ENV_FILE="${WOW_ENV:-/usr/local/etc/wow-forever.env}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

APPID="${SteamAppId:-2980947332}"
if [[ "$APPID" == "0" || ${#APPID} -gt 10 ]]; then APPID=2980947332; fi
STEAM_ROOT="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-/root/.local/share/Steam}"
SHIM="${WOW_SIGSHIM:-/usr/local/lib/libsigctx_zero.so}"
TEBSTUB_OFFSETS="${WOW_TEBSTUB_OFFSETS:-b0a68:43240}"

find_prefix() {
  local exe dir
  if [[ -n "${WOW_PREFIX:-}" ]]; then
    printf '%s\n' "$WOW_PREFIX"
    return 0
  fi
  if [[ -n "${BNET_APPID:-}" ]]; then
    printf '%s\n' "$STEAM_ROOT/steamapps/compatdata/$BNET_APPID"
    return 0
  fi
  shopt -s nullglob
  for exe in "$STEAM_ROOT/steamapps/compatdata/"*/pfx/drive_c/Program\ Files\ \(x86\)/World\ of\ Warcraft/_classic_beta_/WowB-ARM64.exe; do
    dir="${exe%/pfx/drive_c/*}"
    if [[ -d "$dir" ]]; then
      printf '%s\n' "$dir"
      shopt -u nullglob
      return 0
    fi
  done
  shopt -u nullglob
  return 1
}

PREFIX="$(find_prefix)" || { echo "Launch-WoW: no WoW install in any Proton prefix (set BNET_APPID)" >&2; exit 1; }
WOW_ROOT="${WOW_ROOT:-$PREFIX/pfx/drive_c/Program Files (x86)/World of Warcraft}"
WOW="$WOW_ROOT/_classic_beta_"
EXE="$WOW/WowB-ARM64.exe"
LOGDIR="${WOW_LOGDIR:-/tmp/wow-launch}"
LOG="$LOGDIR/proton-launch.log"

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

TOOL="$(find_tool)" || { echo "Launch-WoW: no DroidDeck-Proton wrap" >&2; exit 1; }
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
  if [[ ! -e "$f" ]]; then echo "Launch-WoW: missing $f"; exit 1; fi
done
if [[ -z "$ICD" || ! -r "$ICD" ]]; then
  echo "Launch-WoW: no session Vulkan ICD (pick a driver in DroidDeck)"
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

pre="${LD_PRELOAD:-}"
pre="${pre//\/root\/.steam\/bin32\/gameoverlayrenderer.so/}"
pre="${pre##:}"; pre="${pre%%:}"
export LD_PRELOAD="${pre:+$pre:}$SHIM"
echo "LD_PRELOAD=$LD_PRELOAD WINE_TEBSTUB_OFFSETS=$WINE_TEBSTUB_OFFSETS VK_ICD_FILENAMES=${VK_ICD_FILENAMES:-}"

for p in $(pgrep -x WowB-ARM64.exe 2>/dev/null); do
  echo "killing stale WowB pid $p"; kill -9 "$p"
done

SYS32="$PREFIX/pfx/drive_c/windows/system32"
if [[ -f "$SYS32/ntdll.dll" ]] && ! cmp -s "$NTDLL_SRC" "$SYS32/ntdll.dll"; then
  cp -f "$NTDLL_SRC" "$SYS32/ntdll.dll.bl-new" && mv -f "$SYS32/ntdll.dll.bl-new" "$SYS32/ntdll.dll"
  echo "synced patched ntdll.dll into prefix"
fi

PORTAL="${WOW_PORTAL:-test}"
CFG="$WOW/WTF/Config.wtf"
mkdir -p "$WOW/WTF"
if ! grep -q "^SET portal \"$PORTAL\"" "$CFG" 2>/dev/null; then
  sed -i "/^SET portal /d" "$CFG" 2>/dev/null || true
  echo "SET portal \"$PORTAL\"" >>"$CFG"
  echo "cvar portal=$PORTAL"
fi

STAMPER="${WOW_STAMPER:-/usr/local/bin/droiddeck-steamgame-stamp.sh}"
if [[ -x "$STAMPER" ]]; then
  "$STAMPER" "$APPID" $$ "${DISPLAY:-:1}" >>"$LOGDIR/stamper.log" 2>&1 &
  echo "stamper pid $!"
fi

cd "$WOW" || exit 1
echo "exec proton waitforexitandrun $EXE -d3d11"
"$PROTON" waitforexitandrun "$EXE" -d3d11
rc=$?
echo "proton-exit $rc"
exit "$rc"
