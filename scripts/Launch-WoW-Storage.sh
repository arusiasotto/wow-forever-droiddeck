#!/bin/bash
# Launch WowB-ARM64.exe with DroidDeck-Proton from a Steam non-Steam shortcut.
#
# Configure in DroidDeck / Steam (no script edits required for a normal setup):
#   - Non-Steam shortcut: Linux target Launch-WoW.sh (or this script)
#   - Shortcut → Compatibility → DroidDeck-Proton build with WoW tier-8 fixes
#   - Session → Linux Vulkan driver (Turnip, etc.)
# Steam sets on Play: SteamAppId, STEAM_COMPAT_DATA_PATH, STEAM_COMPAT_TOOL_PATHS,
#   STEAM_COMPAT_CLIENT_INSTALL_PATH, and usually VK_ICD_* / BL_VK_DRIVER.
#
# Optional overrides (env file or export before launch):
#   WOW_ENV              path to env file (default /usr/local/etc/wow-forever-storage.env)
#   WOW_ROOT             game tree if not under the prefix (e.g. external Storage/Game)
#   WOW_GAME_DIR         client folder (default: $WOW_ROOT/_classic_beta_)
#   WOW_EXE              full path to client exe (default: $WOW_GAME_DIR/WowB-ARM64.exe)
#   WOW_GAME_ARGS        fallback args if Steam launch options are empty (manual launch)
#   $@                   from Steam shortcut Launch Options (e.g. -d3d11)
#   WOW_PORTAL           if set, ensure SET portal in WTF/Config.wtf
#   WOW_APPID            only for manual launch without SteamAppId
#   WOW_PREFIX           compatdata path if STEAM_COMPAT_DATA_PATH unset
#   WOW_STEAM_ROOT       if STEAM_COMPAT_CLIENT_INSTALL_PATH unset
#   WOW_PROTON_DIR       compat tool if STEAM_COMPAT_TOOL_PATHS unset
#   WOW_STAMPER          gamescope focus helper (default: droiddeck-steamgame-stamp.sh on PATH)
#   WOW_LOGDIR           log directory (default: /tmp/wow-launch-$APPID)
#   WOW_NO_STAMPER       set to 1 to skip stamper (expect no picture on DroidDeck)
set -uo pipefail

ENV_FILE="${WOW_ENV:-/usr/local/etc/wow-forever-storage.env}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

APPID="${SteamAppId:-${SteamGameId:-${WOW_APPID:-}}}"
if [[ "$APPID" == "0" || -z "$APPID" || ${#APPID} -gt 10 ]]; then
  APPID="${WOW_APPID:-}"
fi
if [[ -z "$APPID" ]]; then
  echo "Launch-WoW-Storage: launch from Steam or set WOW_APPID" >&2
  exit 1
fi

STEAM_ROOT="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-${WOW_STEAM_ROOT:-${HOME:-/root}/.local/share/Steam}}"
PREFIX="${STEAM_COMPAT_DATA_PATH:-${WOW_PREFIX:-}}"
if [[ -z "$PREFIX" ]]; then
  PREFIX="$STEAM_ROOT/steamapps/compatdata/$APPID"
fi

PFX_WOW="$PREFIX/pfx/drive_c/Program Files (x86)/World of Warcraft"
WOW_ROOT="${WOW_ROOT:-$PFX_WOW}"
WOW_DIR="${WOW_GAME_DIR:-$WOW_ROOT/_classic_beta_}"
EXE="${WOW_EXE:-$WOW_DIR/WowB-ARM64.exe}"
LOGDIR="${WOW_LOGDIR:-/tmp/wow-launch-$APPID}"
LOG="$LOGDIR/proton-launch.log"
STAMPER="${WOW_STAMPER:-$(command -v droiddeck-steamgame-stamp.sh 2>/dev/null || echo /usr/local/bin/droiddeck-steamgame-stamp.sh)}"

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

TOOL="$(find_tool)" || {
  echo "Launch-WoW-Storage: set Compatibility tool on this shortcut in Steam (DroidDeck)" >&2
  exit 1
}
PROTON="$TOOL/droiddeck-proton-wrap"

ICD="${VK_ICD_FILENAMES:-${VK_DRIVER_FILES:-${BL_VK_DRIVER:-}}}"
ICD="${ICD%%:*}"

mkdir -p "$LOGDIR"
exec >>"$LOG" 2>&1
echo "======== $(date -Iseconds) pid=$$ ========"
echo "appid=$APPID prefix=$PREFIX tool=$TOOL"
echo "exe=$EXE game_dir=$WOW_DIR wow_root=$WOW_ROOT"
echo "session-icd=$ICD steam_compat_data=${STEAM_COMPAT_DATA_PATH:-unset}"

for f in "$PROTON" "$EXE"; do
  if [[ ! -e "$f" ]]; then echo "Launch-WoW-Storage: missing $f"; exit 1; fi
done
if [[ -z "$ICD" || ! -r "$ICD" ]]; then
  echo "Launch-WoW-Storage: no session Vulkan ICD (pick a driver in DroidDeck)"
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

for p in $(pgrep -x WowB-ARM64.exe 2>/dev/null); do
  echo "killing stale WowB pid $p"; kill -9 "$p"
done

if [[ -n "${WOW_PORTAL:-}" ]]; then
  CFG="$WOW_DIR/WTF/Config.wtf"
  mkdir -p "$WOW_DIR/WTF"
  if ! grep -q "^SET portal \"$WOW_PORTAL\"" "$CFG" 2>/dev/null; then
    sed -i "/^SET portal /d" "$CFG" 2>/dev/null || true
    echo "SET portal \"$WOW_PORTAL\"" >>"$CFG"
    echo "cvar portal=$WOW_PORTAL"
  fi
fi

if [[ -z "${WOW_NO_STAMPER:-}" && -x "$STAMPER" ]]; then
  "$STAMPER" "$APPID" $$ "${DISPLAY:-:1}" >>"$LOGDIR/stamper.log" 2>&1 &
  echo "stamper pid $!"
elif [[ -z "${WOW_NO_STAMPER:-}" ]]; then
  echo "Launch-WoW-Storage: warning: stamper missing ($STAMPER)"
fi

# Steam/DroidDeck may inject wrapper tokens (--oom-score-adjust, --, paths). Only pass known WowB flags.
run_args=()
i=1
while [[ $i -le $# ]]; do
  a="${!i}"
  case "$a" in
    -d3d11|-d3d12|-launcherlogin|-skipcinematics|-nosound|-config|-uid)
      run_args+=("$a")
      case "$a" in
        -config|-uid)
          next=$((i + 1))
          if [[ $next -le $# ]]; then
            run_args+=("${!next}")
            i=$next
          fi
          ;;
      esac
      ;;
    *)
      ;;
  esac
  i=$((i + 1))
done
if [[ $# -gt 0 && ${#run_args[@]} -eq 0 ]]; then
  echo "Launch-WoW-Storage: ignored argv ($*); use WOW_GAME_ARGS or Steam launch options -d3d11 only"
fi
if [[ ${#run_args[@]} -eq 0 && -n "${WOW_GAME_ARGS:-}" ]]; then
  # shellcheck disable=SC2206
  run_args=($WOW_GAME_ARGS)
fi
if [[ ${#run_args[@]} -eq 0 ]]; then
  echo "Launch-WoW-Storage: warning: no game args — set WOW_GAME_ARGS=-d3d11 or launch options -d3d11"
fi

cd "$WOW_DIR" || exit 1
echo "exec proton waitforexitandrun $EXE ${run_args[*]:-}"
"$PROTON" waitforexitandrun "$EXE" "${run_args[@]}"
rc=$?
echo "proton-exit $rc"
exit "$rc"
