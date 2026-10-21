#!/bin/bash
# One Steam entry: pick Battle.net or WowB.
#   Launch.sh              → prompt if possible, else play
#   Launch.sh wow          → WowB
#   Launch.sh bnet         → Battle.net
# Existing tiles can keep Launch-WoW.sh / Launch-BattleNet.sh; those call this.
set -uo pipefail

ENV_FILE="${WOW_ENV:-/usr/local/etc/wow-forever.env}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

normalize() {
  local a="${1:-}"
  a="${a,,}"
  a="${a#/}"
  case "$a" in
    wow|game|play|wowb) echo wow ;;
    bnet|battlenet|battle.net|bn|launcher) echo bnet ;;
    *) echo "" ;;
  esac
}

pick() {
  local mode arg
  for arg in "$@"; do
    mode="$(normalize "$arg")"
    if [[ -n "$mode" ]]; then
      printf '%s\n' "$mode"
      return 0
    fi
  done
  mode="$(normalize "${WOW_LAUNCH:-}")"
  if [[ -n "$mode" ]]; then
    printf '%s\n' "$mode"
    return 0
  fi

  export DISPLAY="${DISPLAY:-:1}"
  export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/droiddeck}"
  if command -v zenity >/dev/null 2>&1; then
    local choice
    choice="$(zenity --list --title="WoW Forever" --text="Launch" \
      --column="" --hide-header \
      "World of Warcraft" "Battle.net" 2>/dev/null || true)"
    case "$choice" in
      Battle.net) printf 'bnet\n'; return 0 ;;
      "World of Warcraft") printf 'wow\n'; return 0 ;;
    esac
  fi
  if [[ -t 0 ]]; then
    echo "1) World of Warcraft" >&2
    echo "2) Battle.net" >&2
    local n
    read -r -p "Launch [1]: " n || true
    case "$n" in
      2|b|bnet) printf 'bnet\n'; return 0 ;;
      *) printf 'wow\n'; return 0 ;;
    esac
  fi
  printf 'wow\n'
}

MODE="$(pick "$@")"
case "$MODE" in
  bnet) exec /usr/local/bin/Launch-BattleNet-DroidDeckProton.sh "$@" ;;
  *) exec /usr/local/bin/Launch-WoW-DroidDeckProton.sh "$@" ;;
esac
