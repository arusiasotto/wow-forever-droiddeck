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

## 2. Install launch scripts (guest)

Only **two** files — copy to `/usr/local/bin/`:

| Guest | Repo |
|-------|------|
| `Launch-BattleNet.sh` | [`scripts/Launch-BattleNet.sh`](scripts/Launch-BattleNet.sh) |
| `droiddeck-steamgame-stamp.sh` | [`scripts/droiddeck-steamgame-stamp.sh`](scripts/droiddeck-steamgame-stamp.sh) |

Or from a PC with adb: **`./deprecated/scripts/deploy-battle-net-guest.sh`**

No config file is required on the guest for a standard install.

---

## 3. Battle.net Steam shortcut

| Field | Value |
|--------|--------|
| **Target** | `Battle.net Launcher.exe` |
| **Compatibility tool** | **DroidDeck-Proton 11-9.1 ARM64EC WoW** |
| **Launch options** | `/usr/local/bin/Launch-BattleNet.sh %command%` |

Linux **Vulkan driver** in DroidDeck (Turnip, etc.).

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
