# wow-forever-droiddeck

Install **World of Warcraft** on [DroidDeck](https://github.com/Droid-Deck/DroidDeck) through **Battle.net** — **Retail**, **Classic**, and **Forever** (same setup; you pick the game in the launcher).

Repo name is historical; this is **not** Forever-only.

This repo is **not** the game or Proton. Unofficial — not affiliated with Blizzard, DroidDeck, Valve, or Wine.

Optional adb helpers: [`deprecated/scripts/`](deprecated/scripts/).

---

## Before you start

| Piece | Source |
|--------|--------|
| **DroidDeck** | Phone app + Linux guest |
| **Proton (WoW build)** | [DroidDeck-Proton-WoW-arm64ec releases](https://github.com/arusiasotto/DroidDeck-Proton-WoW-arm64ec) |
| **Launch scripts (this repo)** | **Optional** — only for the [Steam library path](#optional-launch-from-the-steam-client) |

Install Proton once, configure Battle.net once, then use the **skip-Steam** flow below unless you deliberately want the Steam UI path.

---

## 1. Install Proton (guest)

1. Download **`DroidDeck-Proton-11-9.1-arm64ec-wow-aarch64.tar.gz`** to the phone (**Downloads**).
2. In a **root guest shell** (DroidDeck terminal, **Desktop terminal**, or adb `guest` — adjust the path to your Download folder):

   ```bash
   tar -xzf DroidDeck-Proton-11-9.1-arm64ec-wow-aarch64.tar.gz \
     -C /root/.local/share/Steam/compatibilitytools.d
   ```

3. Verify:

   ```bash
   ls "/root/.local/share/Steam/compatibilitytools.d/DroidDeck-Proton 11-9.1 ARM64EC WoW/"
   ```

   You should see `droiddeck-proton-wrap` or `proton`.

**From a PC:** `./deprecated/scripts/install-proton-build-guest.sh /path/to/DroidDeck-Proton-11-9.1-arm64ec-wow-aarch64.zip`

---

## 2. Recommended: launch without opening Steam

This is the path that works best on DroidDeck: **picture and input go to the game**, you can **quit Battle.net after Play**, and you **do not** need scripts from this repo.

### 2a. One-time: Battle.net + Proton in Steam (behind the scenes)

DroidDeck still uses Steam’s **compat tool** and **app id** for Battle.net, even when the Steam window never opens. Do this **once**:

1. In DroidDeck, start a **Steam** session and wait for the library to load.
2. **Add a non-Steam game** (if you have not already): **`Battle.net Launcher.exe`**.  
   Optional: install Battle.net to **Storage** first and point the shortcut at `/root/Storage/Battle.net/Battle.net Launcher.exe`.
3. **Battle.net shortcut → Properties → Compatibility** → force **DroidDeck-Proton 11-9.1 ARM64EC WoW**.
4. **Launch options:** leave **empty** (or `%command%` only). **Do not** install `Launch-BattleNet.sh` for this path.
5. Exit Steam (end the session or go back to DroidDeck). You will not need the Steam UI for normal play.

Also in the **DroidDeck app** (phone):

| Setting | Value |
|---------|--------|
| **Session → Linux Vulkan driver** | One that works for games on your device (e.g. Mesa Turnip A8xx) |
| **Added game / tile for Battle.net** | Same exe: **`Battle.net Launcher.exe`** |
| **Launch options on that tile** | **Empty** (no `--disable-gpu` unless debugging) |

Use **one** Battle.net entry only. Do not add separate tiles that launch `Wow.exe`, `WowClassic`, or `WowB-ARM64.exe` directly — pick Retail / Classic / Forever inside Battle.net.

### 2b. Every play session: skip Steam

1. Open **DroidDeck** on the phone.
2. Start the game using the option that **does not open the Steam client** (wording varies by version; e.g. play from the **DroidDeck library / tile** without a full **Steam** session).  
   You should **not** sit in the Steam library and press Play there for this path.
3. Battle.net opens → log in if needed.
4. Sidebar → **Retail**, **Classic**, or **Forever** → **Play**.
5. Optional: when WoW is in the world, **close Battle.net**; the game keeps running.

**Launch options recap for skip-Steam:** empty or `%command%` on both the DroidDeck tile and the Steam shortcut. No guest scripts required.

### 2c. First-time WoW install (inside Battle.net)

| Step | Action |
|------|--------|
| 1 | Select the WoW **product** you want in the left sidebar. |
| 2 | Install to **`C:\Program Files (x86)\World of Warcraft`** (default). |
| 3 | That product → **gear → Game Settings → Additional command line arguments:** `-d3d11` (set **per product** you play). |
| 4 | **Play**. |

Blizzard uses subfolders such as `_retail_`, `_classic_era_`, and `_classic_beta_` (Forever) under one install root — that is normal.

### 2d. If something goes wrong (skip-Steam path)

| Symptom | What to check |
|---------|----------------|
| Black screen / no Vulkan | Session **Linux driver** in DroidDeck; Proton folder from §1 |
| Wrong WoW product launches | Sidebar selection in Battle.net; remove extra **direct `.exe`** tiles |
| Sluggish Battle.net UI | Remove **`--disable-gpu`** from launch options |
| Game dies when closing Battle.net | You may have used the **Steam library** path; use §2b instead |

---

## Optional: Launch from the Steam client

Use this only if you **want Steam open** (library, downloads, browsing) and launch Battle.net with **Steam’s Play** button.

On many devices, gamescope then keeps focus on **Steam (app 769)** instead of the game — **sound but no picture**. The scripts in this repo fix that by stamping **`STEAM_GAME`** and updating **gamescope focus** on `:0`.

### When to use this path

- You regularly manage games/updates inside the **Steam UI**.
- Skip-Steam (§2) is not available or you prefer Steam’s library.

If skip-Steam works for you, **stay on §2** — no scripts to deploy.

### Setup (one time)

1. **On a PC** with adb to the phone, from this repo:

   ```bash
   ./deprecated/scripts/deploy-battle-net-guest.sh
   ```

   Installs on the guest:

   - [`Launch-BattleNet.sh`](scripts/Launch-BattleNet.sh)
   - [`droiddeck-steamgame-stamp.sh`](scripts/droiddeck-steamgame-stamp.sh)

2. **Steam → Battle.net shortcut → Properties → Launch options:**

   ```text
   /usr/local/bin/Launch-BattleNet.sh %command%
   ```

3. Keep **Compatibility** → **DroidDeck-Proton 11-9.1 ARM64EC WoW** (same as §2a).

4. Start a **Steam** session, open the library, press **Play** on Battle.net.

You do **not** need to change the skip-Steam tile if you use both paths: leave the DroidDeck tile on **empty / `%command%`**, and only add the script line on the **Steam shortcut** used from the library.

### Logs (Steam + script path)

`/tmp/wow-launch-<steam-appid>/bnet-launch.log` (e.g. `4153382437` for Battle.net)

---

## Optional paths (advanced)

Battle.net or WoW on **Storage** instead of the default prefix: copy [`scripts/wow-forever.env.example`](scripts/wow-forever.env.example) to `/usr/local/etc/wow-forever.env` and set `BNET_DIR` / `WOW_ROOT`.

---

## DroidDeck bug reports

Zip the **Downloads → DroidDeck** folder from the phone.

---

## Related

- **Proton build:** [DroidDeck-Proton-WoW-arm64ec](https://github.com/arusiasotto/DroidDeck-Proton-WoW-arm64ec)
- **Upstream patches:** [Droid-Deck/DroidDeck-Proton](https://github.com/Droid-Deck/DroidDeck-Proton)
