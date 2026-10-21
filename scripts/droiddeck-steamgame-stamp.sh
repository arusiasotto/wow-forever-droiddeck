#!/bin/bash
# Stamp STEAM_GAME=<appid> on Proton windows, then point gamescope at them.
# Steam Deck gamescope only shows windows with that atom; the overlay does not
# set it here. STEAM_GAME alone is not enough when Steam launched a failed
# interstitial first — GAMESCOPE_FOCUSED_* on :0 is what moves the picture.
#
# Usage: droiddeck-steamgame-stamp.sh <appid> <parent-pid> [game-display]
set -u
APPID=$1; PARENT=$2; DPY=${3:-:1}
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/droiddeck}"

XTREE=$(cat <<'EOF'
import ctypes, ctypes.util, sys
X = ctypes.CDLL(ctypes.util.find_library("X11") or "libX11.so.6")
X.XOpenDisplay.restype = ctypes.c_void_p; X.XOpenDisplay.argtypes = [ctypes.c_char_p]
X.XDefaultRootWindow.restype = ctypes.c_ulong; X.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
UL = ctypes.c_ulong
X.XQueryTree.argtypes = [ctypes.c_void_p, UL, ctypes.POINTER(UL), ctypes.POINTER(UL), ctypes.POINTER(ctypes.POINTER(UL)), ctypes.POINTER(ctypes.c_uint)]
class XWA(ctypes.Structure):
    _fields_ = [("x", ctypes.c_int), ("y", ctypes.c_int), ("width", ctypes.c_int), ("height", ctypes.c_int),
                ("border", ctypes.c_int), ("depth", ctypes.c_int), ("visual", ctypes.c_void_p), ("root", UL),
                ("cls", ctypes.c_int), ("bit_gravity", ctypes.c_int), ("win_gravity", ctypes.c_int),
                ("backing_store", ctypes.c_int), ("backing_planes", UL), ("backing_pixel", UL),
                ("save_under", ctypes.c_int), ("colormap", UL), ("map_installed", ctypes.c_int),
                ("map_state", ctypes.c_int), ("all_event_masks", ctypes.c_long), ("your_event_mask", ctypes.c_long),
                ("dnd", ctypes.c_long), ("override_redirect", ctypes.c_int), ("screen", ctypes.c_void_p)]
X.XGetWindowAttributes.argtypes = [ctypes.c_void_p, UL, ctypes.POINTER(XWA)]
d = X.XOpenDisplay(None)
if not d: sys.exit(0)
root = X.XDefaultRootWindow(d)
r = UL(); p = UL(); ch = ctypes.POINTER(UL)(); n = ctypes.c_uint()
if X.XQueryTree(d, root, ctypes.byref(r), ctypes.byref(p), ctypes.byref(ch), ctypes.byref(n)):
    for i in range(n.value):
        a = XWA(); X.XGetWindowAttributes(d, ch[i], ctypes.byref(a))
        if a.map_state == 2 and not a.override_redirect and a.width > 64 and a.height > 64:
            print(f"0x{ch[i]:x}")
EOF
)

gamescope_focus() {
  local wid_hex="$1" wid
  wid=$((wid_hex))
  DISPLAY=:0 xprop -root -f GAMESCOPE_FOCUSED_APP 32c -set GAMESCOPE_FOCUSED_APP "$APPID" 2>/dev/null || true
  DISPLAY=:0 xprop -root -f GAMESCOPE_FOCUSED_APP_GFX 32c -set GAMESCOPE_FOCUSED_APP_GFX "$APPID" 2>/dev/null || true
  DISPLAY=:0 xprop -root -f GAMESCOPE_FOCUSED_WINDOW 32c -set GAMESCOPE_FOCUSED_WINDOW "$wid" 2>/dev/null || true
  DISPLAY=:0 xprop -root -f GAMESCOPECTRL_BASELAYER_WINDOW 32c -set GAMESCOPECTRL_BASELAYER_WINDOW "$wid" 2>/dev/null || true
}

export DISPLAY="$DPY"
focused=
while kill -0 "$PARENT" 2>/dev/null; do
  for w in $(python3 -c "$XTREE" 2>/dev/null); do
    props=$(xprop -id "$w" STEAM_GAME WM_CLASS 2>/dev/null)
    case "$props" in
      *steam_app_*|*"WM_CLASS(STRING) = \"explorer.exe\""*)
        case "$props" in
          *"STEAM_GAME(CARDINAL)"*) ;;
          *)
            xprop -id "$w" -f STEAM_GAME 32c -set STEAM_GAME "$APPID" 2>/dev/null \
              && echo "stamped $w STEAM_GAME=$APPID ($(echo "$props" | grep WM_CLASS | cut -c1-80))"
            ;;
        esac
        if [[ -z "$focused" ]]; then
          gamescope_focus "$w"
          echo "gamescope focus $APPID window $w"
          focused=$w
        fi
        ;;
    esac
  done
  sleep 2
done
