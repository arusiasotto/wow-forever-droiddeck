# wow-forever-droiddeck

Setup scripts for **World of Warcraft** on [DroidDeck](https://github.com/Droid-Deck/DroidDeck) via the **Battle.net Steam shortcut** and **Play** in the client (same Proton prefix as the launcher).

This repo is **not** the game or Proton — only two launch helpers on the guest.

Unofficial. Not affiliated with Blizzard, DroidDeck, Valve, or Wine.

Older experiments live under **[deprecated/](deprecated/)**.

---

## 1. Install Proton (WoW build)

1. **[DroidDeck-Proton-WoW-arm64ec → Releases](https://github.com/arusiasotto/DroidDeck-Proton-WoW-arm64ec/releases)** — download the latest **`DroidDeck-Proton-11-9.1-arm64ec-wow-aarch64.tar.gz`**.
2. On the DroidDeck **guest** (root):

   ```bash
   TOOLS=/root/.local/share/Steam/compatibilitytools.d
   mkdir -p "$TOOLS"
   tar -xzf /path/to/DroidDeck-Proton-11-9.1-arm64ec-wow-aarch64.tar.gz -C "$TOOLS"
   ```

3. After restart, Steam **Compatibility** → **`DroidDeck-Proton 11-9.1 ARM64EC WoW`** on the Battle.net shortcut.

   Other games on this tool are **unverified** (we test WoW via Battle.net; Hollow Knight was a one-off x86 spot-check).

---

## 2. Install scripts (guest)

Copy **two** files to `/usr/local/bin/` (or run **`./scripts/deploy-battle-net-guest.sh`** from a host with adb):

| Guest path | Repo file |
|------------|-----------|
| `/usr/local/bin/Launch-BattleNet.sh` | `scripts/Launch-BattleNet.sh` |
| `/usr/local/bin/droiddeck-steamgame-stamp.sh` | `scripts/droiddeck-steamgame-stamp.sh` |

No **`/usr/local/etc/wow-forever.env`** is required. A standard install uses Steam’s prefix, app id, compat tool, and session Vulkan ICD. Optional overrides: see **`scripts/wow-forever.env.example`** (only create `/usr/local/etc/wow-forever.env` if you need custom paths or FEX flags).

---

## 3. Battle.net Steam shortcut

| Field | Value |
|--------|--------|
| **Target** | `Battle.net Launcher.exe` |
| **Compatibility tool** | **DroidDeck-Proton 11-9.1 ARM64EC WoW** |
| **Launch options** | `/usr/local/bin/Launch-BattleNet.sh %command%` |

Pick a **Linux Vulkan driver** in DroidDeck (Turnip, etc.).

---

## 4. Install WoW and play

1. Launch Battle.net from the shortcut.
2. Install the game to **`C:\Program Files (x86)\World of Warcraft`** (Battle.net default).
3. **Battle.net → game → Settings → Game Settings → Additional command line arguments:**

   ```text
   -d3d11
   ```

4. **Play** from Battle.net.

Do **not** put `d3d11` / `dxgi` in `WINEDLLOVERRIDES`.

Logs (default): `/tmp/wow-launch-<steam-appid>/bnet-launch.log`

---

## Other scripts

| Script | Role |
|--------|------|
| `deploy-battle-net-guest.sh` | adb → install the two launch scripts |
| `install-proton-build-guest.sh` | adb → WoW Proton into `compatibilitytools.d` |
| `rename-proton-wow-tool.sh` / `deploy-rename-proton-guest.sh` | Rename an old Proton folder to **… ARM64EC WoW** |

---

## Related

- **Proton:** [arusiasotto/DroidDeck-Proton-WoW-arm64ec](https://github.com/arusiasotto/DroidDeck-Proton-WoW-arm64ec)
- **Upstream Wine patches:** [Droid-Deck/DroidDeck-Proton](https://github.com/Droid-Deck/DroidDeck-Proton)
