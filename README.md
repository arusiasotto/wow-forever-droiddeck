# WoW Forever on DroidDeck (Hangover + DXVK + Turnip)

World of Warcraft: Forever beta (`WowB-ARM64.exe`, Blizzard's native Windows ARM64
client) running inside the DroidDeck Steam/gamescope session on a Snapdragon 8 Elite
(Adreno 840), launched from the Steam library like any other game.

Reached the world (Menethil Harbor, level 29 character) on 19 October 2026 on a
DroidDeck NX809J. DroidDeck's own Linux session, Mesa Turnip v27 driver and Steam are
untouched; everything added lives under `/opt/hangover`, one Wine prefix and one
Steam shortcut.

> Unofficial. Not affiliated with Blizzard, DroidDeck, Valve, Hangover or Wine.
> This repo contains **no** Blizzard game files and no Wine/Hangover binaries; the
> installer downloads those from their upstream releases.

## How it works

| Layer | What | Why |
|---|---|---|
| Runtime | [Hangover](https://github.com/AndreRH/hangover) 11.16 (glibc aarch64 Wine) at `/opt/hangover` | DroidDeck-Proton ran the client but its init never finished. Hangover's Wine loads it at `0x140000000` and it initialises normally. Hangover = upstream Wine 11.16 + 9 small commits + FEX/Box64 as PE DLLs; the emulator half is never used here because the client is native ARM64. |
| Graphics | DXVK 2.7.1 **plain ARM64** (`dxvk/aarch64` from the Hangover tarball) in `system32`, enabled through the registry | Wine's builtin d3d11 reports a fake GPU with `dx11:false`. The ARM64EC DXVK variant cannot load into a pure ARM64 process. |
| Vulkan | DroidDeck's own Mesa Turnip v27 ICD | Not touched. The ICD path is passed through `VK_ICD_FILENAMES`. |
| Fix 1 | `shim/sigctx_zero.c` (`LD_PRELOAD`) | Wine's ARM64 signal handlers leave `Bcr/Bvr/Wcr/Wvr` in the exception `CONTEXT` uninitialised. The client's vectored handler treats stale bits there as a hardware breakpoint and aborts with **"Game Initialization Failed: I"** on roughly half of launches. The shim zeroes the signal stack before Wine's handler runs. |
| Fix 2 | `scripts/patch-ntdll-teb-table-stub.py` + the shim | The client maps a clean `ntdll.dll` from disk and calls syscalls through it. Wine's ARM64 stubs load `__wine_syscall_dispatcher` from the PE's `.data`, which is zero in a fresh mapping, so the first such call is a `blr` to address 0 and the game hangs right after D3D device creation. The patch rewrites all 264 stubs to fetch the dispatcher from the TEB (`KeServiceDescriptorTable.CounterTable`), and the shim publishes the dispatcher there at startup. |
| Launcher | `scripts/Launch-WoW-Hangover.sh` installed as `/usr/local/bin/Launch-WoW.sh` | Steam non-Steam-game target (Linux, no Proton). Gamescope only focuses windows started by Steam, so launching from a shell shows nothing. |

Two things the client's anti-tamper layer checks that cost a lot of time:

- **Never put `d3d11`/`dxgi` in `WINEDLLOVERRIDES`.** The client scans its environment block and refuses to start. DXVK is enabled via `HKCU\Software\Wine\DllOverrides` instead.
- **Use `SET portal "test"`** in `WTF/Config.wtf`. The default `US` portal authenticates fine but has no beta realms, which shows up as *No realms available* (`GAME_UTILITY_SERVER_NO_SERVER`). The Battle.net launcher normally writes this; a direct launch doesn't. The launcher script enforces it.

## Repo contents

| Path | What |
|---|---|
| `shim/sigctx_zero.c`, `shim/build.sh` | `LD_PRELOAD` shim source and zig cross-build. `shim/libsigctx_zero.so` is the prebuilt. |
| `scripts/patch-ntdll-teb-table-stub.py` | Patches Hangover's `aarch64-windows/ntdll.dll` in place (`.pre-tebstub` backup). Pattern-matched, refuses on an unexpected binary. |
| `scripts/Launch-WoW-Hangover.sh` | The launcher. Idempotent: installs DXVK into the prefix, sets registry overrides, enforces `Config.wtf`, kills a stale client, logs to `/tmp/wow-launch/`. |
| `scripts/wow-hot-threads.py` | Diagnostic: which client threads are burning CPU. |

## Known limitations

- The shim hardcodes two offsets into Hangover 11.16's stripped `ntdll.so` (dispatcher `+0x3a4e0`, `KeServiceDescriptorTable` `+0xa09a0`). It sanity-checks both before writing and disables Fix 2 with a warning on mismatch, but a Hangover update needs new offsets (`WINE_TEBSTUB_OFFSETS=<table>:<disp>`).
- Game updates: when Blizzard patches the beta, the realm list disappears until `WowB-ARM64.exe`, its companion DLLs and `.build.info` are updated on the device. No updater yet.
- Audio, controller mapping and performance tuning are not yet looked at. Resolution is whatever `Config.wtf` says (currently 1590x720 windowed).

## Status / roadmap

1. Installer for other DroidDeck users (`install.sh` on the guest, pinned Hangover download, patch, prefix, Steam shortcut).
2. Launcher: try the Battle.net launcher under Hangover (FEX) first; fall back to a script launcher with a CDN updater.
3. Upstream both Wine fixes as source patches.
