# wow-forever-droiddeck

Helper scripts for Blizzard’s ARM64 Forever client (`WowB-ARM64.exe`) on
[DroidDeck](https://github.com/Droid-Deck/DroidDeck) with a **tier-8 DroidDeck-Proton**
build. This repo is **not** the game or the Proton zip.

Unofficial. Not affiliated with Blizzard, DroidDeck, Valve, or Wine.

## Start here

**[docs/PLAY-FROM-BATTLENET.md](docs/PLAY-FROM-BATTLENET.md)** — install Proton under a
**distinct compatibility tool name**, copy stamper + peeled Battle.net launchers,
configure the Battle.net Steam shortcut, set **`-d3d11`** in Battle.net, **Play**.

No `libsigctx_zero`, no runtime ntdll patch scripts on the peeled path.

## Proton package naming

Do **not** install tier-8 over stock `DroidDeck-Proton 11-9.1` if you rely on DroidDeck
updates — use a separate folder, e.g. `DroidDeck-Proton 11-9.1 ARM64EC WoW`, and select
it per shortcut in Steam. Details in the play doc.

## Minimal guest install (peeled path)

```bash
# On the DroidDeck guest (root), from this repo:
install -m 0755 scripts/droiddeck-steamgame-stamp.sh /usr/local/bin/
install -m 0755 scripts/droiddeck-steam-stamper-wrap.sh /usr/local/bin/
install -m 0755 scripts/Launch-BattleNet.sh /usr/local/bin/
install -m 0755 scripts/Launch-BattleNet-Proton.sh /usr/local/bin/
install -m 0644 scripts/wow-forever.env.example /usr/local/etc/
# Optional: WoW direct tile
install -m 0755 scripts/Launch-WoW.sh /usr/local/bin/
install -m 0755 scripts/Launch-WoW-Storage.sh /usr/local/bin/
install -m 0644 scripts/wow-forever-storage.env.example /usr/local/etc/wow-forever-storage.env
```

Or use `scripts/deploy-battle-net-guest.sh` / `deploy-storage-game-guest.sh` from a
host with `adb`.

## Optional WoW Steam shortcut

See `scripts/wow-forever-storage.env.example` — **Exe** `Launch-WoW.sh`, **launch
options** `-d3d11` only.

## Legacy

`install.sh` + `Launch-*-DroidDeckProton.sh` + `libsigctx_zero.so` — pre–tier-8
workaround stack; kept for rollback, not the recommended path.

Never put `d3d11` or `dxgi` in `WINEDLLOVERRIDES`.
