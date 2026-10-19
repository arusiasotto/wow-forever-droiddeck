#!/bin/bash
# DroidDeck helper: run WoW Forever (WowB-ARM64.exe) under Hangover (glibc
# aarch64 Wine 11.16) instead of DroidDeck-Proton.  Steam runs this as a Linux
# target (no Proton on the shortcut).  Session linuxDriver stays Mesa A8xx.
#
# Why Hangover: DroidDeck-Proton 11-9.1 ran the ARM64X client natively but its
# obfuscated init spun forever.  Under Hangover the client loads at
# 0x140000000 and initialises normally.
#
# Two things the anti-tamper layer cares about (both learned the hard way):
#  * Do NOT put d3d11/dxgi in WINEDLLOVERRIDES.  WowB scans the environment
#    block and refuses to start ("Game Initialization Failed: I").  DXVK is
#    enabled via HKCU\Software\Wine\DllOverrides in the registry instead.
#  * Wine's ARM64 signal handlers leave the hardware debug registers in the
#    exception CONTEXT uninitialised; WowB's VEH treats stale bits there as a
#    hardware breakpoint and bails.  libsigctx_zero.so (LD_PRELOAD) zeroes the
#    signal stack before Wine's handler runs.  See driver/sigctx_zero.c.
set -uo pipefail

HANGOVER="${WOW_HANGOVER:-/opt/hangover}"
SHIM="${WOW_SIGSHIM:-$HANGOVER/libsigctx_zero.so}"
DXVK_DIR="${WOW_DXVK_DIR:-$HANGOVER/dxvk/aarch64}"
export WINEPREFIX="${WOW_WINEPREFIX:-/root/hopfx}"
WOW="${WOW_ROOT:-/root/Storage/Game}/_classic_beta_"
EXE="$WOW/WowB-ARM64.exe"
ICD="${WOW_ICD:-/data/user/0/com.droiddeck.launcher/files/linux_vulkan_drivers/Mesa_Turnip_v27.0.0-20261018-r3-A8xx-Linux/icd.json}"
LOGDIR="${WOW_LOGDIR:-/tmp/wow-launch}"
LOG="$LOGDIR/hangover-launch.log"
WINELOG="$LOGDIR/hangover-wine.log"
DXVK_LOGS="$LOGDIR/dxvk"

mkdir -p "$LOGDIR" "$DXVK_LOGS"
exec >>"$LOG" 2>&1
echo "======== $(date -Iseconds) pid=$$ ========"
echo "prefix=$WINEPREFIX hangover=$HANGOVER icd=$ICD"

for f in "$HANGOVER/usr/bin/wine" "$SHIM" "$EXE" "$ICD"; do
  if [[ ! -e "$f" ]]; then echo "Launch-WoW-Hangover: missing $f"; exit 1; fi
done

export PATH="$HANGOVER/usr/bin:$PATH"
export DISPLAY="${DISPLAY:-:0}"
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/droiddeck}"
unset WAYLAND_DISPLAY                      # tested path is winex11 under gamescope
export VK_ICD_FILENAMES="$ICD"
export VK_DRIVER_FILES="$ICD"
export WINEDLLOVERRIDES="mscoree,mshtml="   # never list d3d11/dxgi here (see header)
export WINEDEBUG="${WOW_WINEDEBUG:-+loaddll,+err}"
export WINEESYNC="${WOW_WINEESYNC:-1}"
export LANG="${WOW_LANG:-en_US.UTF-8}"
export LC_ALL="${WOW_LC_ALL:-en_US.UTF-8}"
export DXVK_LOG_LEVEL="${WOW_DXVK_LOG_LEVEL:-info}"
export DXVK_LOG_PATH="$DXVK_LOGS"
unset DXVK_CONFIG

# Steam's 32-bit overlay cannot load here and spams the log; drop it, keep the rest.
pre="${LD_PRELOAD:-}"
pre="${pre//\/root\/.steam\/bin32\/gameoverlayrenderer.so/}"
pre="${pre##:}"; pre="${pre%%:}"
export LD_PRELOAD="${pre:+$pre:}$SHIM"
echo "LD_PRELOAD=$LD_PRELOAD"

# Stop a stale client from a previous run in this prefix (never wineserver -k:
# that severs the DroidDeck agent connection).
for p in $(pgrep -x WowB-ARM64.exe 2>/dev/null); do
  if grep -qz "WINEPREFIX=$WINEPREFIX" "/proc/$p/environ" 2>/dev/null; then
    echo "killing stale WowB pid $p"; kill -9 "$p"
  fi
done

if [[ ! -f "$WINEPREFIX/system.reg" ]]; then
  echo "initialising prefix"
  wineboot -u >>"$WINELOG" 2>&1
  wineserver -w
fi

# DXVK: plain ARM64 build into system32, enabled through the registry.
SYS32="$WINEPREFIX/drive_c/windows/system32"
for dll in d3d11 dxgi d3d10core d3d9; do
  if [[ -f "$DXVK_DIR/$dll.dll" ]] && ! cmp -s "$DXVK_DIR/$dll.dll" "$SYS32/$dll.dll"; then
    mkdir -p "$WINEPREFIX/dxvk-backup"
    [[ -f "$SYS32/$dll.dll" && ! -f "$WINEPREFIX/dxvk-backup/$dll.dll" ]] && cp -a "$SYS32/$dll.dll" "$WINEPREFIX/dxvk-backup/"
    cp -f "$DXVK_DIR/$dll.dll" "$SYS32/$dll.dll"
    echo "dxvk installed $dll.dll"
  fi
done
if ! grep -q '"d3d11"="native,builtin"' "$WINEPREFIX/user.reg" 2>/dev/null; then
  for dll in d3d11 dxgi d3d10core d3d9; do
    wine reg add 'HKCU\Software\Wine\DllOverrides' /v "$dll" /t REG_SZ /d 'native,builtin' /f >/dev/null 2>&1
  done
  echo "dxvk registry overrides set"
fi

# Beta clients must talk to the "test" portal.  The Battle.net launcher normally
# writes this; launched directly the client defaults to "US" (live), where
# logon succeeds but the realm list comes back GAME_UTILITY_SERVER_NO_SERVER.
PORTAL="${WOW_PORTAL:-test}"
CFG="$WOW/WTF/Config.wtf"
mkdir -p "$WOW/WTF"
if ! grep -q "^SET portal \"$PORTAL\"" "$CFG" 2>/dev/null; then
  sed -i '/^SET portal /d' "$CFG" 2>/dev/null
  echo "SET portal \"$PORTAL\"" >>"$CFG"
  echo "portal set to $PORTAL"
fi

cd "$WOW" || exit 1
echo "exec wine $EXE -d3d11 (wine-log $WINELOG)"
: >"$WINELOG"
wine "$EXE" -d3d11 >>"$WINELOG" 2>&1
rc=$?
echo "wine-exit $rc"
wineserver -w
tail -n 12 "$WOW/Logs/gx.log" 2>/dev/null || true
exit "$rc"
