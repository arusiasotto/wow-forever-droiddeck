#!/usr/bin/env python3
"""Fix the WoW non-Steam shortcut so Steam launches Launch-WoW.sh as Linux."""

from __future__ import annotations

import re
import shutil
import struct
import sys
from pathlib import Path


def parse(data: bytes, i: int = 0):
    obj = {}
    while i < len(data):
        t = data[i]
        i += 1
        if t == 8:
            return obj, i
        z = data.index(0, i)
        name = data[i:z]
        i = z + 1
        if t == 0:
            child, i = parse(data, i)
            obj[name] = (0, child)
        elif t == 1:
            z = data.index(0, i)
            obj[name] = (1, data[i:z])
            i = z + 1
        elif t == 2:
            obj[name] = (2, struct.unpack_from("<I", data, i)[0])
            i += 4
        else:
            raise ValueError(f"unsupported vdf type {t} at {i}")
    return obj, i


def dump(obj: dict) -> bytes:
    out = bytearray()
    for name, (t, val) in obj.items():
        out.append(t)
        out += name + b"\x00"
        if t == 0:
            out += dump(val)
            out.append(8)
        elif t == 1:
            out += val + b"\x00"
        elif t == 2:
            out += struct.pack("<I", val)
    return bytes(out)


def load_shortcuts(path: Path):
    data = path.read_bytes()
    if data[:1] != b"\x00":
        raise SystemExit(f"{path}: not a binary VDF")
    z = data.index(0, 1)
    root_name = data[1:z]
    root, end = parse(data, z + 1)
    if end < len(data) and data[end] == 8:
        end += 1
    return root_name, root


def save_shortcuts(path: Path, root_name: bytes, root: dict) -> None:
    path.write_bytes(b"\x00" + root_name + b"\x00" + dump(root) + b"\x08")


def s(entry: dict, key: bytes) -> str:
    item = entry.get(key)
    if not item or item[0] != 1:
        return ""
    return item[1].decode("utf-8", "replace")


def set_str(entry: dict, key: bytes, value: str) -> None:
    entry[key] = (1, value.encode("utf-8"))


def fix_shortcuts(path: Path) -> list[str]:
    notes = []
    root_name, root = load_shortcuts(path)
    for key, (t, entry) in list(root.items()):
        if t != 0:
            continue
        name = s(entry, b"AppName")
        exe = s(entry, b"Exe")
        if "World of Warcraft" not in name and "Launch-WoW" not in exe:
            continue
        set_str(entry, b"Exe", "/usr/local/bin/Launch-WoW.sh")
        set_str(entry, b"StartDir", "/usr/local/bin/")
        set_str(entry, b"LaunchOptions", "")
        notes.append(f"shortcuts: {name or key!r} -> Launch-WoW.sh, empty launch options")
    if not notes:
        raise SystemExit("no World of Warcraft shortcut found")
    bak = path.with_suffix(path.suffix + ".pre-wowfix")
    if not bak.exists():
        shutil.copy2(path, bak)
    save_shortcuts(path, root_name, root)
    return notes


def strip_compat(config: Path, appid: str) -> str | None:
    text = config.read_text(encoding="utf-8", errors="replace")
    # CompatToolMapping entries are indented more than two tabs and contain "name".
    # Do not strip ShaderCacheSize / SizeOnDisk blocks that reuse the same appid.
    pat = re.compile(
        rf'\n(\t+)"{re.escape(appid)}"\n\1\{{\n(?:\1\t"[^"]+"\t+"[^"]*"\n)*\1\t"name"\t+"[^"]*"\n(?:\1\t"[^"]+"\t+"[^"]*"\n)*\1\}}'
    )
    new, n = pat.subn("", text, count=1)
    if n == 0:
        # Fallback: any indent, require a "name" field in the mapping body.
        pat = re.compile(
            rf'\n(\t+)"{re.escape(appid)}"\n\1\{{\n(?:\1\t.*\n)*?\1\}}'
        )
        matches = list(pat.finditer(text))
        n = 0
        for m in matches:
            if '"name"' in m.group(0):
                new = text[: m.start()] + text[m.end() :]
                n = 1
                break
        if n == 0:
            return None
    bak = config.with_suffix(config.suffix + ".pre-wowfix")
    if not bak.exists():
        shutil.copy2(config, bak)
    config.write_text(new, encoding="utf-8")
    return f"config.vdf: removed CompatToolMapping {appid}"


def main() -> int:
    steam = Path(sys.argv[1] if len(sys.argv) > 1 else "/root/.local/share/Steam")
    shortcuts = next(steam.glob("userdata/*/config/shortcuts.vdf"))
    config = steam / "config" / "config.vdf"
    for line in fix_shortcuts(shortcuts):
        print(line)
    if config.is_file():
        note = strip_compat(config, "2980947332")
        print(note or "config.vdf: no CompatToolMapping 2980947332")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
