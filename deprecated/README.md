# Deprecated

Not required to **launch Battle.net** (only [`scripts/Launch-BattleNet.sh`](../scripts/Launch-BattleNet.sh) + [`scripts/droiddeck-steamgame-stamp.sh`](../scripts/droiddeck-steamgame-stamp.sh)).

| Path | Contents |
|------|-----------|
| `scripts/deploy-battle-net-guest.sh` | adb push of the two launch scripts |
| `scripts/install-proton-build-guest.sh` | adb + Proton tarball into `compatibilitytools.d` |
| `scripts/rename-proton-wow-tool.sh` | Rename old Proton folder to **… ARM64EC WoW** |
| `scripts/deploy-rename-proton-guest.sh` | adb wrapper for rename |
| `scripts/wow-forever.env.example` | Optional `/usr/local/etc/wow-forever.env` overrides |
| `scripts/Launch-WoW*`, `Launch-*-DroidDeckProton.sh`, … | Direct WoW tile, legacy shim stack |
| `dist/`, `shim/`, `addons/` | Old bundles and experiments |

Supported flow: **[README.md](../README.md)**.
