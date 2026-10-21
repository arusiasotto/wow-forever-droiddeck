# Play WoW from Battle.net (recommended)

Install a **separate** compatibility tool (tier-8 Proton), copy two small helper
scripts, point the **Battle.net** Steam shortcut at them, install from Battle.net, set
**`-d3d11`** in the Battle.net client, then **Play**. No `libsigctx_zero`, no Python
ntdll patchers, no WoW Steam tile required.

## 1. Proton package (avoid overwriting stock DroidDeck-Proton)

DroidDeck may replace the stock **`DroidDeck-Proton 11-9.1`** folder when it updates.
Ship and install your build under the **WoW-tagged** name (folder, Steam label, release tag, and
tarball all include `WoW` / `-wow`):

```text
~/.local/share/Steam/compatibilitytools.d/DroidDeck-Proton 11-9.1 ARM64EC WoW
```

Release example: `DroidDeck-Proton-11-9.1-arm64ec-wow-aarch64.tar.gz` (tag `DroidDeck-Proton-11-9.1-arm64ec-wow`).
Do **not** install builds whose internal id is `DroidDeck-Proton-11-9.1-arm64ec` without `-wow` — DroidDeck
can overwrite those.

On an existing install named like stock `DroidDeck-Proton 11-9.1 ARM64EC`, run
`scripts/rename-proton-wow-tool.sh` on the guest (or `deploy-rename-proton-guest.sh`
from a host with adb).

The name must match the folder inside your zip and the **`compatibilitytool.vdf`**
/`toolmanifest.vdf` entry. Users pick that tool in **Properties → Compatibility** on
the Battle.net (and optional WoW) shortcut. Leave stock **DroidDeck-Proton** for other
games.

Tier-8 Wine fixes live **in that build** (ARM64EC ntdll, dispatch, NLS, etc.) — not in
`install.sh` patch scripts.

## 2. Helper scripts on the guest

From this repo, install at least:

| File | Role |
|------|------|
| `droiddeck-steamgame-stamp.sh` | Gamescope `STEAM_GAME` / focus |
| `droiddeck-steam-stamper-wrap.sh` | Start stamper, then exec real launch |
| `Launch-BattleNet.sh` | Entry: wrap → peeled launcher |
| `Launch-BattleNet-Proton.sh` | Proton + Battle.net.exe (no shim) |

Optional env: `/usr/local/etc/wow-forever.env` (see `scripts/wow-forever.env.example`).

Session: choose a **Linux Vulkan driver** in DroidDeck (Turnip, etc.). Scripts only
verify an ICD is present.

## 3. Battle.net Steam shortcut

| Field | Value |
|--------|--------|
| **Target** | `Battle.net Launcher.exe` (your install path) |
| **Compatibility tool** | Your **tier-8** tool (distinct folder name above) |
| **Launch options** | `/usr/local/bin/Launch-BattleNet.sh %command%` |

Flow:

```text
Steam → Launch-BattleNet.sh %command%
     → droiddeck-steam-stamper-wrap.sh
     → Launch-BattleNet-Proton.sh
     → droiddeck-proton-wrap waitforexitandrun Battle.net Launcher.exe
```

Set **`BNET_NO_STAMPER=1`** in `wow-forever.env` so the peeled launcher does not start a
second stamper (the wrap already did).

**FEX:** DroidDeck-Proton’s `proton` script configures FEX on aarch64. If Battle.net
(x86) misbehaves, add optional `FEX_*` vars in `wow-forever.env` (see example file).

## 4. Install WoW

1. Launch **Battle.net** from the shortcut.
2. Install **World of Warcraft** / Forever to  
   `C:\Program Files (x86)\World of Warcraft`  
   (or set `WOW_ROOT` in env and symlink — see example env).

## 5. `-d3d11` (Battle.net only)

**Battle.net** → WoW product → **Settings** → **Game Settings** → **Additional command
line arguments**:

```text
-d3d11
```

Agent passes this on **Play**. Do **not** put `d3d11` / `dxgi` in `WINEDLLOVERRIDES`.

## 6. Play

**Play** from Battle.net. WowB runs **ARM64** under Wine tier 8; Battle.net UI/agent
run **x86** under FEX inside the same Proton tool.

Logs: `/tmp/wow-launch/bnet-launch.log` (default `WOW_LOGDIR`), stamper lines may appear
in `/tmp/wow-launch/stamper.log` from earlier runs.

## Optional: direct WoW Steam shortcut

For a second install path (e.g. `/root/Storage/Game` + prefix `2980947332`):

- `Launch-WoW.sh` → stamper-wrap → `Launch-WoW-Storage.sh`
- **Exe:** `/usr/local/bin/Launch-WoW.sh`
- **Launch options:** `-d3d11` only (not `Launch-WoW.sh %command%` on a Linux target)
- Env: `wow-forever-storage.env` (`WOW_ROOT`, `WOW_GAME_ARGS=-d3d11`, `WOW_NO_STAMPER=1`)

## Legacy

`Launch-BattleNet-DroidDeckProton.sh` (shim + ntdll sync + inline stamper) remains in
the repo for rollback; the peeled path above is what we use after tier 8.
