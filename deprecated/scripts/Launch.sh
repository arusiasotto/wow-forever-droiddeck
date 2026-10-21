#!/bin/bash
# One Steam entry: pick Battle.net or WowB.
#   Launch.sh wow          → WowB
#   Launch.sh bnet         → Battle.net
#   Launch.sh              → play, unless WOW_LAUNCH=bnet|wow|ask
# Do not prompt from Steam Game Mode: a hidden tty or zenity sheet hangs forever.
set -uo pipefail

ENV_FILE="${WOW_ENV:-/usr/local/etc/wow-forever.env}"
if [[ -f "$ENV_FILE" ]]; then
  # shellcheck disable=SC1090
  . "$ENV_FILE"
fi

normalize() {
  local a="${1:-}"
  a="${a,,}"
  a="${a##*/}"
  a="${a%.sh}"
  case "$a" in
    wow|game|play|wowb|launch-wow) echo wow ;;
    bnet|battlenet|battle.net|bn|launcher|launch-battlenet) echo bnet ;;
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
  if [[ -n "$mode" && "$mode" != "ask" ]]; then
    printf '%s\n' "$mode"
    return 0
  fi
  if [[ "${WOW_LAUNCH:-}" == "ask" && -t 0 ]]; then
    echo "1) World of Warcraft" >&2
    echo "2) Battle.net" >&2
    local n
    read -r -t 20 -p "Launch [1]: " n || true
    case "$n" in
      2|b|bnet) printf 'bnet\n'; return 0 ;;
    esac
  fi
  printf 'wow\n'
}

MODE="$(pick "$@")"
case "$MODE" in
  bnet) exec /usr/local/bin/Launch-BattleNet-Proton.sh ;;
  *) exec /usr/local/bin/Launch-WoW-DroidDeckProton.sh ;;
esac
