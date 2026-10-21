#!/usr/bin/env python3
"""Restore the WoW shortcut to the last launch that reached the game.

Target: droiddeck-steam-stamper-wrap.sh with Launch-WoW.sh -d3d11 as its args (gamescope focus)
Compat tool is left alone. Battle.net is left alone.
"""

from __future__ import annotations

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


def main() -> int:
    steam = Path(sys.argv[1] if len(sys.argv) > 1 else "/root/.local/share/Steam")
    path = next(steam.glob("userdata/*/config/shortcuts.vdf"))
    root_name, root = load_shortcuts(path)
    names = []
    wow = None
    for _key, (t, entry) in root.items():
        if t != 0:
            continue
        name = s(entry, b"AppName")
        names.append(name)
        if name == "World of Warcraft":
            wow = entry
    if "Battle.net" not in names or wow is None:
        raise SystemExit(f"refusing to write; found {names}")
    set_str(wow, b"Exe", '"/usr/local/bin/Launch-WoW.sh"')
    set_str(wow, b"StartDir", '"/usr/local/bin/"')
    set_str(wow, b"LaunchOptions", "-d3d11")
    bak = path.with_name("shortcuts.vdf.before-restore")
    shutil.copy2(path, bak)
    save_shortcuts(path, root_name, root)
    root_name, root = load_shortcuts(path)
    for _key, (t, entry) in root.items():
        if t != 0:
            continue
        print(s(entry, b"AppName"))
        print("  Exe", s(entry, b"Exe"))
        print("  StartDir", s(entry, b"StartDir"))
        print("  LaunchOptions", s(entry, b"LaunchOptions"))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
