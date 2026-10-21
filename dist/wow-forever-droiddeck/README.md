# WoW Forever on DroidDeck

Helpers so Blizzard’s native ARM64 Forever client (`WowB-ARM64.exe`) can run
under DroidDeck-Proton. This zip is **not** the game.

Unofficial. Not affiliated with Blizzard, DroidDeck, Valve or Wine.

## What you still install yourself

1. DroidDeck Steam session.
2. **DroidDeck-Proton** (11-9.1 is the tested tool) and a **GPU driver** of your choice.
3. Battle.net, then WoW Forever onto `C:\Program Files (x86)\World of Warcraft` in that Proton prefix. Agent will not update a copy on G: or a random folder.

## Install these helpers

Copy this folder onto the deck and, as root:

```bash
chmod +x install.sh
./install.sh
```

That copies the launchers and `libsigctx_zero.so`, patches every
DroidDeck-Proton PE `ntdll.dll` (TEB stubs) and unix `ntdll.so` (NLS
fallback, skipped if the binary layout does not match), and writes
`/usr/local/etc/wow-forever.env`.

## Steam shortcuts

One script: `/usr/local/bin/Launch.sh`

- No argument: zenity/tty picker if available, otherwise play
- `Launch.sh wow` — WowB
- `Launch.sh bnet` — Battle.net

You can keep two tiles (`Launch-WoW.sh` / `Launch-BattleNet.sh %command%`)
or one tile pointed at `Launch.sh`. Launch from the Steam library
(gamescope). A raw shell window will not focus.

Install Forever from Battle.net onto the default C: path.

The play script finds `WowB-ARM64.exe` in any prefix. If it misses, put the
Battle.net shortcut’s compatdata folder name in `/usr/local/etc/wow-forever.env`:

```bash
BNET_APPID=4153382437
```

Play from the WoW tile. Battle.net Play works, but closing the launcher kills WowB.

## What these scripts do

- Inherit the session GPU ICD and Proton. They do not pin a Turnip build.
- `LD_PRELOAD` `libsigctx_zero.so` (stops “Game Initialization Failed: I”).
- TEB-table ntdll stubs so WowB’s copied `ntdll.dll` can still make syscalls.
- `SET portal "test"` so the beta realm list appears.
- Stamp `STEAM_GAME` so gamescope focuses the Proton window.

Never put `d3d11` or `dxgi` in `WINEDLLOVERRIDES`.

## Limits

- TEB offsets default to Proton **11-9.1** (`b0a68:43240`). `install.sh` tries
  `nm` on `ntdll.so` and writes what it finds. A newer Proton may need a new pair
  in `wow-forever.env` as `WOW_TEBSTUB_OFFSETS=table:dispatcher`.
- NLS fallback is applied when `ntdll.so` matches Proton **11-9.1**. A newer
  Proton is left untouched.
- Addons and graphics CVars are not included. Tune those after you are in-world.
