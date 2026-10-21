# wow-forever-droiddeck

Setup scripts for **World of Warcraft Forever** (`WowB-ARM64.exe`) on [DroidDeck](https://github.com/Droid-Deck/DroidDeck). This repo does **not** include the game or Proton — only launch helpers.

Unofficial. Not affiliated with Blizzard, DroidDeck, Valve, or Wine.

---

## 1. Install Proton (WoW build)

1. Open **[DroidDeck-Proton-WoW-arm64ec → Releases](https://github.com/arusiasotto/DroidDeck-Proton-WoW-arm64ec/releases)** and download the latest **`DroidDeck-Proton-11-9.1-arm64ec-wow-aarch64.tar.gz`** (pre-release is fine until marked stable).
2. On the DroidDeck **guest** (root shell), extract into Steam’s compatibility tools directory:

   ```bash
   TOOLS=/root/.local/share/Steam/compatibilitytools.d
   mkdir -p "$TOOLS"
   tar -xzf /path/to/DroidDeck-Proton-11-9.1-arm64ec-wow-aarch64.tar.gz -C "$TOOLS"
   ```

3. Confirm the folder exists:

   ```text
   /root/.local/share/Steam/compatibilitytools.d/DroidDeck-Proton 11-9.1 ARM64EC WoW
   ```

4. Restart Steam. In **Properties → Compatibility** you should see **`DroidDeck-Proton 11-9.1 ARM64EC WoW`**.

   Use this tool **only** for Battle.net / WoW shortcuts. Keep stock **`DroidDeck-Proton 11-9.1`** (or GE) for other games so DroidDeck updates do not replace your WoW build.

   **From a PC with adb:** push the tarball to the phone (e.g. `Download/`), then extract from a guest session. `scripts/install-proton-build-guest.sh` expects a release **zip** layout; for a bare `.tar.gz`, use the `tar` command above or adapt the path in that script.

---

## 2. Install these scripts (guest)

Copy the scripts below to `/usr/local/bin/` (and optional env files to `/usr/local/etc/`).

**Battle.net path (recommended):**

| Install as | From repo |
|------------|-----------|
| `/usr/local/bin/droiddeck-steamgame-stamp.sh` | `scripts/droiddeck-steamgame-stamp.sh` |
| `/usr/local/bin/droiddeck-steam-stamper-wrap.sh` | `scripts/droiddeck-steam-stamper-wrap.sh` |
| `/usr/local/bin/Launch-BattleNet.sh` | `scripts/Launch-BattleNet.sh` |
| `/usr/local/bin/Launch-BattleNet-Proton.sh` | `scripts/Launch-BattleNet-Proton.sh` |
| `/usr/local/etc/wow-forever.env` | copy from `scripts/wow-forever.env.example` and edit if needed |

**From a host with adb:**

```bash
./scripts/deploy-battle-net-guest.sh
```

Set `ADB_SERIAL` if your device is not the default in the script.

---

## 3. Battle.net Steam shortcut

| Field | Value |
|--------|--------|
| **Target** | `Battle.net Launcher.exe` (your install) |
| **Compatibility tool** | **DroidDeck-Proton 11-9.1 ARM64EC WoW** |
| **Launch options** | `/usr/local/bin/Launch-BattleNet.sh %command%` |

In DroidDeck, pick a **Linux Vulkan driver** (Turnip, etc.) for the session.

In **`wow-forever.env`**, set **`BNET_NO_STAMPER=1`** so the launcher does not start a second gamescope stamper (the wrap script already did).

---

## 4. Install the game and set `-d3d11`

1. Launch Battle.net from the shortcut.
2. Install WoW to **`C:\Program Files (x86)\World of Warcraft`** (default). Override paths in `wow-forever.env` only if you know you need a symlink layout (`WOW_ROOT`, `BNET_DIR` — see the example file).
3. **Battle.net → WoW → Settings → Game Settings → Additional command line arguments:**

   ```text
   -d3d11
   ```

4. **Play** from Battle.net.

Do **not** put `d3d11` or `dxgi` in `WINEDLLOVERRIDES`.

Logs (default): `/tmp/wow-launch/bnet-launch.log` (`WOW_LOGDIR` in env).

---

## 5. Optional: WoW without Battle.net (Storage / Game)

If you keep the game under **`/root/Storage/Game`** and a separate Steam tile:

| Install as | From repo |
|------------|-----------|
| `/usr/local/bin/Launch-WoW.sh` | `scripts/Launch-WoW.sh` |
| `/usr/local/bin/Launch-WoW-Storage.sh` | `scripts/Launch-WoW-Storage.sh` |
| `/usr/local/etc/wow-forever-storage.env` | copy from `scripts/wow-forever-storage.env.example` |

**Shortcut:** target **`Launch-WoW.sh`**, same Proton tool, launch options **`-d3d11` only** (not `Launch-WoW.sh %command%`).

```bash
./scripts/deploy-storage-game-guest.sh
```

---

## Script index

| Script | Purpose |
|--------|---------|
| `Launch-BattleNet.sh` | Steam entry → stamper wrap → Proton launcher |
| `Launch-BattleNet-Proton.sh` | Runs Battle.net under the compat tool |
| `Launch-WoW.sh` / `Launch-WoW-Storage.sh` | Direct WoW tile (Storage layout) |
| `droiddeck-steam-stamper-wrap.sh` | Gamescope focus / `STEAM_GAME` stamper |
| `droiddeck-steamgame-stamp.sh` | Stamper helper |
| `deploy-battle-net-guest.sh` | adb deploy for §2 |
| `deploy-storage-game-guest.sh` | adb deploy for §5 |
| `install-proton-build-guest.sh` | adb push + extract Proton zip/tar (WoW-tagged tool only) |
| `rename-proton-wow-tool.sh` | Guest: rename an old ARM64EC folder to **… ARM64EC WoW** |
| `Launch-*-DroidDeckProton.sh`, `install.sh`, `shim/` | **Legacy** pre–tier-8 path; not recommended |

Utility scripts (`fix-wow-launch-options.py`, `fix-steam-wow-shortcut.py`, etc.) are for repairing Steam shortcut metadata on the guest.

---

## Related

- **Proton (tier 8, WoW-tagged releases):** [arusiasotto/DroidDeck-Proton-WoW-arm64ec](https://github.com/arusiasotto/DroidDeck-Proton-WoW-arm64ec)
- **Upstream Proton PR (same Wine patches, stock naming):** [Droid-Deck/DroidDeck-Proton](https://github.com/Droid-Deck/DroidDeck-Proton)
