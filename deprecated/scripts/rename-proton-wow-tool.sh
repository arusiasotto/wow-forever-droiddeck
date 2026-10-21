#!/bin/bash
# Rename the tier-8 Proton install so DroidDeck stock updates do not overwrite it.
# Run on the DroidDeck guest as root (or via deploy-rename-proton-guest.sh).
set -euo pipefail

STEAM="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-/root/.local/share/Steam}"
TOOLS="$STEAM/compatibilitytools.d"
OLD_NAME="${OLD_PROTON_NAME:-DroidDeck-Proton 11-9.1 ARM64EC}"
NEW_NAME="${NEW_PROTON_NAME:-DroidDeck-Proton 11-9.1 ARM64EC WoW}"

OLD="$TOOLS/$OLD_NAME"
NEW="$TOOLS/$NEW_NAME"

if [[ ! -d "$OLD" ]]; then
  if [[ -d "$NEW" ]]; then
    echo "Already renamed: $NEW"
    exit 0
  fi
  echo "Missing: $OLD" >&2
  ls -1d "$TOOLS"/DroidDeck-Proton* 2>/dev/null || true
  exit 1
fi

if [[ -e "$NEW" ]]; then
  echo "Refusing to overwrite existing: $NEW" >&2
  exit 1
fi

mv -- "$OLD" "$NEW"
echo "Renamed folder -> $NEW"

python3 <<PY
import re
from pathlib import Path

steam = Path("$STEAM")
old, new = """$OLD_NAME""", """$NEW_NAME"""
vdf = Path("$NEW") / "compatibilitytool.vdf"
if vdf.is_file():
    t = vdf.read_text(encoding="utf-8", errors="replace")
    t2 = re.sub(r'("display_name"\\s*")[^"]*(")', r"\\1" + new + r"\\2", t, count=1)
    vdf.write_text(t2, encoding="utf-8")
    print("compatibilitytool.vdf display_name ->", new)
for cfg in steam.glob("userdata/*/config/config.vdf"):
    text = cfg.read_text(encoding="utf-8", errors="replace")
    if old not in text:
        continue
    bak = cfg.with_suffix(cfg.suffix + ".pre-proton-rename")
    if not bak.exists():
        bak.write_text(text, encoding="utf-8")
    cfg.write_text(text.replace(old, new), encoding="utf-8")
    print(f"updated CompatToolMapping strings in {cfg}")
PY

echo "Done. In Steam, re-check Properties → Compatibility for Battle.net and WoW shortcuts."
echo "Pick: $NEW"
