#!/usr/bin/env python3
"""Make Wine ARM64 ntdll.dll syscall stubs survive being manually mapped.

WowB-ARM64.exe maps a clean copy of ntdll.dll from disk, relocates it and
calls Nt* through that copy (anti-hook).  On Windows that is fine because a
stub is just `svc #id; ret`.  Wine 11.x emits

    mov  x8, #id
    mov  x9, x30
    ldr  x16, <pc-literal>      ; &__wine_syscall_dispatcher (PE .data)
    ldr  x16, [x16]
    blr  x16
    ret
    .quad <literal>

and in a fresh copy that .data variable is still zero -> call to address 0.

This rewrites every stub to a form that only depends on the TEB:

    mov  x8, #id
    mov  x9, x30
    ldr  x16, [x18, #0x370]     ; teb_data->syscall_table (KeServiceDescriptorTable)
    ldr  x16, [x16, #8]         ; .CounterTable: unused by Wine, filled with the
    blr  x16                    ;   dispatcher address by libsigctx_zero.so
    ret
    .quad <literal unchanged>   ; keeps the existing .reloc entry harmless

Usage: patch-ntdll-teb-table-stub.py <ntdll.dll> [more ntdll.dll ...]
A .pre-tebstub backup is written next to each file on first use.
"""

from __future__ import annotations

import shutil
import struct
import sys
from pathlib import Path

# after `mov x8,#id`: mov x9,x30 | ldr x16,lit | ldr x16,[x16] | blr x16 | ret
OLD_TAIL = bytes.fromhex("e9031eaa" "90000058" "100240f9" "00023fd6" "c0035fd6")
# mov x9,x30 | ldr x16,[x18,#0x370] | ldr x16,[x16,#8] | blr x16 | ret
NEW_TAIL = bytes.fromhex("e9031eaa" "50ba41f9" "100640f9" "00023fd6" "c0035fd6")
assert len(OLD_TAIL) == len(NEW_TAIL) == 20


def patch(data: bytearray) -> int:
    n = 0
    i = 0
    while i <= len(data) - 24:
        if data[i + 4 : i + 24] == OLD_TAIL:
            w0 = struct.unpack_from("<I", data, i)[0]
            if (w0 & 0xFFE0001F) == 0xD2800008:  # movz x8, #imm16
                data[i + 4 : i + 24] = NEW_TAIL
                n += 1
                i += 32
                continue
        i += 4
    return n


def main(argv: list[str]) -> int:
    if len(argv) < 2:
        print(__doc__)
        return 2
    for arg in argv[1:]:
        path = Path(arg)
        data = bytearray(path.read_bytes())
        already = data.count(NEW_TAIL)
        n = patch(data)
        if n == 0 and already:
            print(f"{path}: already patched ({already} stubs)")
            continue
        if n < 100:
            print(f"{path}: only {n} stubs matched, refusing", file=sys.stderr)
            return 1
        bak = path.with_name(path.name + ".pre-tebstub")
        if not bak.exists():
            shutil.copy2(path, bak)
        tmp = path.with_name(path.name + ".tmp")
        tmp.write_bytes(data)
        tmp.chmod(path.stat().st_mode & 0o7777)
        tmp.replace(path)  # atomic; running processes keep the old mapping
        print(f"{path}: patched {n} stubs (backup {bak.name})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
