# wow-forever-droiddeck

Install **World of Warcraft** on [DroidDeck](https://github.com/Droid-Deck/DroidDeck) through **Battle.net** — **Retail**, **Classic**, and **Forever** (same setup; you pick the game in the launcher).

Repo name is historical; this is **not** Forever-only.

This repo is **not** the game or Proton. Unofficial — not affiliated with Blizzard, DroidDeck, Valve, or Wine.

Optional adb helpers: [`deprecated/scripts/`](deprecated/scripts/).

---

## Installation checklist

Do these **in order**. Skip nothing unless the step says optional.

### A. On your phone (outside the Linux guest)

| # | Do this | Check |
|---|---------|--------|
| A1 | Install **DroidDeck** and open it. | App runs, device supported. |
| A2 | Download **`DroidDeck-Proton-11-9.1-arm64ec-wow-aarch64.tar.gz`** ([release](https://github.com/arusiasotto/DroidDeck-Proton-WoW-arm64ec/releases)) to **Downloads**. | File on phone storage. |
| A3 | (Optional) Put **Battle.net** on DroidDeck **Storage**, or add it later as a **non-Steam game** in the guest. | You know where `Battle.net Launcher.exe` will live. |

### B. Inside the DroidDeck Linux guest (Proton)

You need a **root shell** in the guest once (DroidDeck terminal / adb `guest` — however you usually run commands there).

| # | Do this | Check |
|---|---------|--------|
| B1 | Extract Proton into Steam’s tool folder (adjust the path to your Download mount, often `/root/Storage/Download/` or `/sdcard/Download/`): | Folder exists on disk. |
|   | `tar -xzf DroidDeck-Proton-11-9.1-arm64ec-wow-aarch64.tar.gz -C /root/.local/share/Steam/compatibilitytools.d` | |
| B2 | Confirm: `ls "/root/.local/share/Steam/compatibilitytools.d/DroidDeck-Proton 11-9.1 ARM64EC WoW/"` | Contains `droiddeck-proton-wrap` or `proton`. |

**From a PC instead of typing in the guest:**  
`./deprecated/scripts/install-proton-build-guest.sh /path/to/DroidDeck-Proton-11-9.1-arm64ec-wow-aarch64.zip`

### C. DroidDeck app settings (session + Battle.net entry)

| # | Do this | Check |
|---|---------|--------|
| C1 | **Session:** choose a **Linux Vulkan driver** that works for games on your phone (e.g. Mesa Turnip A8xx). | Steam/games render, not a black screen. |
| C2 | Add **one** game entry for **Battle.net** only (DroidDeck “added game” / adopt Storage / non-Steam game). | One launcher for all WoW products. |
| C3 | **Executable:** `Battle.net Launcher.exe` (not `Battle.net.exe` alone). | Matches your install folder. |
| C4 | **Launch options:** leave **empty** (recommended). Do **not** use `--disable-gpu` unless you are debugging a GPU crash. | Empty or `%command%` only. |
| C5 | **How to start:** prefer **launch without opening the Steam client** (DroidDeck option on the tile). | Avoids gamescope focus issues. |

**Do not** add extra DroidDeck shortcuts that launch a WoW `.exe` directly (`Wow.exe`, `WowClassic`, `WowB-ARM64.exe`, etc.). Use Battle.net → select product → **Play** so the correct client and updates apply.
### D. Steam compatibility (inside guest, for the Battle.net shortcut)

Start a **Steam** session once. In the Steam library, open the **Battle.net** shortcut → **Properties** (or Manage → Properties):

| Field | Set to |
|--------|--------|
| **Compatibility** | Force: **DroidDeck-Proton 11-9.1 ARM64EC WoW** |
| **Launch options** | Empty, or `%command%` (same as C4) |

**Only if you always launch from the Steam library UI** (Steam stays open on screen): see [Steam focus workaround](#steam-focus-workaround-optional) below.

### E. First-time Battle.net + WoW install

| # | Do this | Check |
|---|---------|--------|
| E1 | Launch **Battle.net** from your DroidDeck tile (step C). | Launcher opens, you can log in. |
| E2 | Left sidebar → select the **WoW product** you want (**Retail**, **Classic**, or **Forever**). | Correct art / title for that game. |
| E3 | Install (or update) to **`C:\Program Files (x86)\World of Warcraft`** (default). | Install completes. |
| E4 | That product → gear → **Game Settings** → **Additional command line arguments:** `-d3d11` | Set per product you play (each has its own gear menu). |
| E5 | Press **Play**. | The client for **that** product starts. |

All products share one install root; Blizzard uses subfolders such as `_retail_`, `_classic_era_`, and `_classic_beta_` (Forever) — that is normal.

After the game is up, you may **close Battle.net**; WoW keeps running if you used the recommended launch path (C5).

### F. Every login after that

1. Start **Battle.net** (same tile as E1).  
2. Sidebar → the **WoW product** you want.  
3. **Play**.

If the **wrong** WoW starts, the other product was selected in the sidebar, or a **direct `.exe` shortcut/tile** is still installed — remove extra tiles and use Battle.net only.

---

## Steam focus workaround (optional)

Use this **only** when you launch Battle.net from the **Steam client** while Steam is on screen and you get **sound but no picture**.

1. On PC: `./deprecated/scripts/deploy-battle-net-guest.sh`  
2. Steam → Battle.net shortcut → **Launch options:**  
   `/usr/local/bin/Launch-BattleNet.sh %command%`

Scripts: [`Launch-BattleNet.sh`](scripts/Launch-BattleNet.sh), [`droiddeck-steamgame-stamp.sh`](scripts/droiddeck-steamgame-stamp.sh).

---

## Optional paths (advanced)

If Battle.net or game files live on **Storage** instead of the default Proton prefix, copy [`scripts/wow-forever.env.example`](scripts/wow-forever.env.example) to `/usr/local/etc/wow-forever.env` on the guest and set `BNET_DIR` / `WOW_ROOT`. Not needed for a default install.

---

## Logs

| When | Where |
|------|--------|
| Using `Launch-BattleNet.sh` | `/tmp/wow-launch-<steam-appid>/bnet-launch.log` |
| DroidDeck bug report | Phone **Downloads → DroidDeck** (zip the folder) |

---

## Related

- **Proton build:** [DroidDeck-Proton-WoW-arm64ec](https://github.com/arusiasotto/DroidDeck-Proton-WoW-arm64ec)
- **Upstream patches:** [Droid-Deck/DroidDeck-Proton](https://github.com/Droid-Deck/DroidDeck-Proton)
