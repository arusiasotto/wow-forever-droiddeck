#!/bin/bash
# Steam WoW shortcut entry: stamper wrap → storage launcher; -d3d11 from launch options only.
export WOW_ENV="${WOW_ENV:-/usr/local/etc/wow-forever-storage.env}"
exec /usr/local/bin/droiddeck-steam-stamper-wrap.sh /usr/local/bin/Launch-WoW-Storage.sh "$@"
