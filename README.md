# wow-forever-droiddeck

Setup scripts for **World of Warcraft Forever** on [DroidDeck](https://github.com/Droid-Deck/DroidDeck) via the **Battle.net Steam shortcut** and **Play** in the client (`WowB-ARM64.exe` in the same Proton prefix).

This repo is **not** the game or Proton — only launch helpers for the Battle.net container.

Unofficial. Not affiliated with Blizzard, DroidDeck, Valve, or Wine.

Older direct-WoW / Storage tiles and pre–tier-8 stacks live under **[deprecated/](deprecated/)**.

---

## 1. Install Proton (WoW build)

1. **[DroidDeck-Proton-WoW-arm64ec → Releases](https://github.com/arusiasotto/DroidDeck-Proton-WoW-arm64ec/releases)** — download the latest **`DroidDeck-Proton-11-9.1-arm64ec-wow-aarch64.tar.gz`**.
2. On the DroidDeck **guest** (root):

   ```bash
   TOOLS=/root/.local/share/Steam/compatibilitytools.d
   mkdir -p "$TOOLS"
   tar -xzf /path/to/DroidDeck-Proton-11-9.1-arm64ec-wow-aarch64.tar.gz -C "$TOOLS"
   ```

3. Folder must be:

   ```text
   …/compatibilitytools.d/DroidDeck-Proton 11-9.1 ARM64EC WoW
   ```

4. Restart Steam → **Properties → Compatibility** → **`DroidDeck-Proton 11-9.1 ARM64EC WoW`**.

   Assign this tool to your **Battle.net** shortcut. Using it for **other games is unverified** (we only test WoW via Battle.net on this build, and Hollow Knight).

   **adb:** `scripts/install-proton-build-guest.sh` (release zip) or extract the `.tar.gz` manually (see above).

---

## 2. Install scripts (guest)

| Install as | From repo |
|------------|-----------|
| `/usr/local/bin/droiddeck-steamgame-stamp.sh` | `scripts/droiddeck-steamgame-stamp.sh` |
| `/usr/local/bin/Launch-BattleNet.sh` | `scripts/Launch-BattleNet.sh` |
| `/usr/local/etc/wow-forever.env` | copy from `scripts/wow-forever.env.example` (edit paths if needed) |

**Host with adb:**

```bash
./scripts/deploy-battle-net-guest.sh
```

(`ADB_SERIAL` if needed.)

---

## 3. Battle.net Steam shortcut

| Field | Value |
|--------|--------|
| **Target** | `Battle.net Launcher.exe` |
| **Compatibility tool** | **DroidDeck-Proton 11-9.1 ARM64EC WoW** |
| **Launch options** | `/usr/local/bin/Launch-BattleNet.sh %command%` |

Pick a **Linux Vulkan driver** in DroidDeck (Turnip, etc.).

**Focus:** `Launch-BattleNet.sh` starts **`droiddeck-steamgame-stamp.sh`** in the background, then runs Proton. Only these **two** scripts are required on the guest.

---

## 4. Install WoW and play

1. Launch Battle.net from the shortcut.
2. Install WoW to **`C:\Program Files (x86)\World of Warcraft`** (default). Optional overrides: `BNET_DIR`, `WOW_ROOT` in `wow-forever.env`.
3. **Battle.net → WoW → Settings → Game Settings → Additional command line arguments:**

   ```text
   -d3d11
   ```

4. **Play** from Battle.net.

Do **not** put `d3d11` / `dxgi` in `WINEDLLOVERRIDES`.

Logs (default): `/tmp/wow-launch/<appid>/bnet-launch.log` (`WOW_LOGDIR` in env).

---

## Scripts (supported)

| Script | Role |
|--------|------|
| `Launch-BattleNet.sh` | Steam entry: stamper + Proton + Battle.net |
| `droiddeck-steamgame-stamp.sh` | Gamescope `STEAM_GAME` / focus loop |
| `deploy-battle-net-guest.sh` | adb install §2 |
| `install-proton-build-guest.sh` | adb + WoW-tagged Proton into `compatibilitytools.d` |
| `rename-proton-wow-tool.sh` | Guest: rename old Proton folder to **… ARM64EC WoW** |
| `deploy-rename-proton-guest.sh` | adb wrapper for rename script |

---

## Related

- **Proton:** [arusiasotto/DroidDeck-Proton-WoW-arm64ec](https://github.com/arusiasotto/DroidDeck-Proton-WoW-arm64ec)
- **Upstream Wine patches:** [Droid-Deck/DroidDeck-Proton](https://github.com/Droid-Deck/DroidDeck-Proton)
