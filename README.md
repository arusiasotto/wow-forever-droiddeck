# wow-forever-droiddeck

Launch scripts for **World of Warcraft** on [DroidDeck](https://github.com/Droid-Deck/DroidDeck): **Battle.net Steam shortcut** → **Play** in the client.

This repo is **not** the game or Proton.

Unofficial. Not affiliated with Blizzard, DroidDeck, Valve, or Wine.

Setup helpers (adb deploy, Proton install, optional env) live under **[deprecated/scripts/](deprecated/scripts/)**.

---

## 1. Install Proton (WoW build)

1. **[DroidDeck-Proton-WoW-arm64ec → Releases](https://github.com/arusiasotto/DroidDeck-Proton-WoW-arm64ec/releases)** — **`DroidDeck-Proton-11-9.1-arm64ec-wow-aarch64.tar.gz`**.
2. Guest (root):

   ```bash
   tar -xzf DroidDeck-Proton-11-9.1-arm64ec-wow-aarch64.tar.gz -C /root/.local/share/Steam/compatibilitytools.d
   ```

3. Steam **Compatibility** on the Battle.net shortcut → **`DroidDeck-Proton 11-9.1 ARM64EC WoW`**.

---

## 2. How DroidDeck launches the game

DroidDeck can start the shortcut **without opening the Steam client**. That path usually **does not need** the focus helper scripts (picture and input work with plain Steam launch options).

If you **open Steam** in the session (library, updates, browsing) and launch Battle.net from there, gamescope often keeps focus on **Steam (app 769)** instead of Battle.net — **sound but no picture**. For that path, use the **launcher + stamper** in §3.

| DroidDeck behavior | Launch options (Battle.net shortcut) | Guest scripts |
|--------------------|--------------------------------------|---------------|
| **Launch without Steam** (recommended) | `%command%` | Optional — not required for focus |
| **Steam running / launch from Steam UI** | `/usr/local/bin/Launch-BattleNet.sh %command%` | **Required:** [`Launch-BattleNet.sh`](scripts/Launch-BattleNet.sh) + [`droiddeck-steamgame-stamp.sh`](scripts/droiddeck-steamgame-stamp.sh) in `/usr/local/bin/` |

Install the two scripts (adb: **`./deprecated/scripts/deploy-battle-net-guest.sh`**) if you use the Steam-in-session column. No `/usr/local/etc/wow-forever.env` needed for a standard install.

Disabling the **in-game Steam overlay** alone did **not** fix the focus issue in our testing; the split above matches what we saw on device.

---

## 3. Battle.net Steam shortcut

| Field | Value |
|--------|--------|
| **Target** | `Battle.net Launcher.exe` |
| **Compatibility tool** | **DroidDeck-Proton 11-9.1 ARM64EC WoW** |
| **Launch options** | See §2 (`%command%` or `Launch-BattleNet.sh %command%`) |

Pick a **Linux Vulkan driver** in DroidDeck (Turnip, etc.).

---

## 4. WoW and play

1. Open Battle.net from the shortcut.
2. Install to **`C:\Program Files (x86)\World of Warcraft`** (default).
3. **Game Settings → Additional command line arguments:** `-d3d11`
4. **Play**

Logs: `/tmp/wow-launch-<steam-appid>/bnet-launch.log`

---

## Related

- **Proton:** [arusiasotto/DroidDeck-Proton-WoW-arm64ec](https://github.com/arusiasotto/DroidDeck-Proton-WoW-arm64ec)
- **Upstream patches:** [Droid-Deck/DroidDeck-Proton](https://github.com/Droid-Deck/DroidDeck-Proton)
