#!/usr/bin/env python3
"""Force WoW shortcut LaunchOptions to -d3d11 (Linux exe must not use %command%)."""

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
            z2 = data.index(0, i)
            obj[name] = (1, data[i:z2])
            i = z2 + 1
        elif t == 2:
            obj[name] = (2, struct.unpack("<i", data[i : i + 4])[0])
            i += 4
        elif t == 7:
            obj[name] = (7, struct.unpack("<Q", data[i : i + 8])[0])
            i += 8
        else:
            raise ValueError(f"unknown type {t} at {i}")
    return obj, i


def s(entry, key: bytes) -> str:
    v = entry.get(key)
    if not v or v[0] != 1:
        return ""
    return v[1].decode("utf-8", errors="replace")


def set_str(entry, key: bytes, val: str) -> None:
    entry[key] = (1, val.encode("utf-8"))


def emit_obj(obj) -> bytes:
    out = bytearray()
    for name, (t, val) in obj.items():
        out.append(t)
        out.extend(name + b"\x00")
        if t == 0:
            out.extend(emit_obj(val))
            out.append(8)
        elif t == 1:
            out.extend(val + b"\x00")
        elif t == 2:
            out.extend(struct.pack("<i", val))
        elif t == 7:
            out.extend(struct.pack("<Q", val))
    return bytes(out)


def save_shortcuts(path: Path, root_name: bytes, root: dict) -> None:
    body = emit_obj(root)
    path.write_bytes(b"\x00" + root_name + b"\x00" + body + b"\x08")


def load_shortcuts(path: Path):
    data = path.read_bytes()
    assert data[0] == 0
    z = data.index(0, 1)
    root_name = data[1:z]
    root, _ = parse(data, z + 1)
    return root_name, root[root_name][1]


def main() -> int:
    steam = Path(sys.argv[1] if len(sys.argv) > 1 else "/root/.local/share/Steam")
    path = next(steam.glob("userdata/*/config/shortcuts.vdf"))
    root_name, root = load_shortcuts(path)
    for _key, (t, entry) in root.items():
        if t != 0:
            continue
        if s(entry, b"AppName") != "World of Warcraft":
            continue
        old = s(entry, b"LaunchOptions")
        set_str(entry, b"LaunchOptions", "-d3d11")
        bak = path.with_name("shortcuts.vdf.before-launchopts")
        shutil.copy2(path, bak)
        save_shortcuts(path, root_name, root)
        print(f"World of Warcraft LaunchOptions: {old!r} -> '-d3d11'")
        return 0
    print("World of Warcraft shortcut not found", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
