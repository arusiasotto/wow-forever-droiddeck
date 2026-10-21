#!/bin/bash
# Background helper: stamp STEAM_GAME=<appid> on game windows gamescope has not
# claimed yet.  Gamescope (Steam Deck mode) focuses only windows carrying the
# STEAM_GAME atom; the Steam overlay normally sets it, but under DroidDeck-Proton
# it does not, so the game renders on :1 while gamescope keeps showing Steam.
# Gamescope reacts to the property change immediately.
#
# Usage: droiddeck-steamgame-stamp.sh <appid> <parent-pid> [display]
set -u
APPID=$1; PARENT=$2; DPY=${3:-:1}
export DISPLAY="$DPY" XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/droiddeck}"

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

while kill -0 "$PARENT" 2>/dev/null; do
  for w in $(python3 -c "$XTREE" 2>/dev/null); do
    props=$(xprop -id "$w" STEAM_GAME WM_CLASS 2>/dev/null)
    case "$props" in
      *"STEAM_GAME(CARDINAL)"*) continue ;;
    esac
    # Only windows that look like ours: Proton/Wine sets WM_CLASS steam_app_<id>.
    case "$props" in
      *steam_app_*|*"WM_CLASS(STRING) = \"explorer.exe\""*)
        xprop -id "$w" -f STEAM_GAME 32c -set STEAM_GAME "$APPID" 2>/dev/null \
          && echo "stamped $w STEAM_GAME=$APPID ($(echo "$props" | grep WM_CLASS | cut -c1-80))" ;;
    esac
  done
  sleep 2
done
