#!/usr/bin/env python3
"""Add an NLS map-fail fallback to DroidDeck-Proton unix ntdll.

90624's NtGetNlsSectionPtr / NtInitializeNlsFiles are the same Wine 11
section-map path as DroidDeck (the 12–24 byte size gap is clang vs gcc).
The community writeup still names an "NLS fallback allocation": if the
file-backed section map fails, malloc the .nls bytes and return that
pointer so locale_init / WowB do not abort.

This patch:
  1. Extends the RX LOAD with a small helper.
  2. NtInitializeNlsFiles: on map failure, read_nls_file("locale.nls").
  3. NtGetNlsSectionPtr: on map failure, try l_intl / c_1252 / c_437.
"""

from __future__ import annotations

import argparse
import shutil
import struct
import sys
from pathlib import Path


def u32(data: bytes, off: int) -> int:
    return struct.unpack_from("<I", data, off)[0]


def p32(val: int) -> bytes:
    return struct.pack("<I", val)


def encode_bl(pc: int, target: int) -> int:
    imm = (target - pc) >> 2
    if imm < -(1 << 25) or imm >= (1 << 25):
        raise ValueError(f"bl out of range {pc:#x} -> {target:#x}")
    return 0x94000000 | (imm & 0x3FFFFFF)


def encode_b(pc: int, target: int) -> int:
    imm = (target - pc) >> 2
    if imm < -(1 << 25) or imm >= (1 << 25):
        raise ValueError(f"b out of range {pc:#x} -> {target:#x}")
    return 0x14000000 | (imm & 0x3FFFFFF)


def encode_cbz_w(rt: int, pc: int, target: int) -> int:
    imm = (target - pc) >> 2
    if imm < -(1 << 18) or imm >= (1 << 18):
        raise ValueError("cbz out of range")
    return 0x34000000 | ((imm & 0x7FFFF) << 5) | rt


def encode_cbz_x(rt: int, pc: int, target: int) -> int:
    imm = (target - pc) >> 2
    if imm < -(1 << 18) or imm >= (1 << 18):
        raise ValueError("cbz x out of range")
    return 0xB4000000 | ((imm & 0x7FFFF) << 5) | rt


def encode_adr(rd: int, pc: int, target: int) -> int:
    imm = target - pc
    if imm < -(1 << 20) or imm >= (1 << 20):
        raise ValueError(f"adr out of range {imm}")
    immlo = imm & 3
    immhi = (imm >> 2) & 0x7FFFF
    return 0x10000000 | (immlo << 29) | (immhi << 5) | rd


def elf_symbol(data: bytes, name: str) -> int:
    e_shoff = struct.unpack_from("<Q", data, 40)[0]
    e_shentsize = struct.unpack_from("<H", data, 58)[0]
    e_shnum = struct.unpack_from("<H", data, 60)[0]
    e_shstrndx = struct.unpack_from("<H", data, 62)[0]

    def shdr(i: int):
        off = e_shoff + i * e_shentsize
        return struct.unpack_from("<IIQQQQIIQQ", data, off)

    shstr = shdr(e_shstrndx)
    shstrtab = data[shstr[4] : shstr[4] + shstr[5]]
    symtab = strtab_full = None
    for i in range(e_shnum):
        sh = shdr(i)
        nm = shstrtab[sh[0] :].split(b"\0", 1)[0]
        if nm == b".symtab":
            symtab = sh
        if nm == b".strtab":
            strtab_full = sh
    if not symtab:
        raise KeyError("no .symtab")
    strb = data[strtab_full[4] : strtab_full[4] + strtab_full[5]]
    entsize = symtab[9] or 24
    for j in range(symtab[5] // entsize):
        off = symtab[4] + j * entsize
        st_name, st_info, st_other, st_shndx, st_value, st_size = struct.unpack_from(
            "<IBBHQQ", data, off
        )
        nm = strb[st_name:].split(b"\0", 1)[0]
        if nm == name.encode():
            return st_value
    raise KeyError(name)


def vma_to_off_elf(data: bytes, vma: int) -> int:
    e_phoff = struct.unpack_from("<Q", data, 32)[0]
    e_phentsize = struct.unpack_from("<H", data, 54)[0]
    e_phnum = struct.unpack_from("<H", data, 56)[0]
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align = (
            struct.unpack_from("<IIQQQQQQ", data, off)
        )
        if p_type == 1 and p_vaddr <= vma < p_vaddr + p_filesz:
            return p_offset + (vma - p_vaddr)
    raise KeyError(hex(vma))


def extend_rx_load(data: bytearray, extra: int) -> int:
    """Grow the first RX PT_LOAD and return the new cave VMA (old filesz)."""
    e_phoff = struct.unpack_from("<Q", data, 32)[0]
    e_phentsize = struct.unpack_from("<H", data, 54)[0]
    e_phnum = struct.unpack_from("<H", data, 56)[0]
    for i in range(e_phnum):
        off = e_phoff + i * e_phentsize
        p_type, p_flags, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, p_align = (
            struct.unpack_from("<IIQQQQQQ", data, off)
        )
        if p_type == 1 and (p_flags & 5) == 5:  # R+X
            cave_vma = p_vaddr + p_filesz
            cave_off = p_offset + p_filesz
            new_fsz = p_filesz + extra
            new_msz = p_memsz + extra
            struct.pack_into("<Q", data, off + 32, new_fsz)
            struct.pack_into("<Q", data, off + 40, new_msz)
            if cave_off + extra > len(data):
                data.extend(b"\x00" * (cave_off + extra - len(data)))
            return cave_vma
    raise RuntimeError("no RX PT_LOAD")


def write_u32s(data: bytearray, off: int, words: list[int]) -> None:
    data[off : off + 4 * len(words)] = b"".join(p32(w) for w in words)


def patch_unix(data: bytearray) -> list[str]:
    notes = []
    read_nls = elf_symbol(bytes(data), "read_nls_file")
    init = elf_symbol(bytes(data), "NtInitializeNlsFiles")
    getnls = elf_symbol(bytes(data), "NtGetNlsSectionPtr")
    notes.append(f"read_nls_file={read_nls:#x}")
    notes.append(f"NtInitializeNlsFiles={init:#x}")
    notes.append(f"NtGetNlsSectionPtr={getnls:#x}")

    cave_vma = extend_rx_load(data, 0x200)
    cave_off = vma_to_off_elf(bytes(data), cave_vma)
    notes.append(f"cave={cave_vma:#x} off={cave_off:#x}")

    # strings at end of cave
    locale = b"locale.nls\0"
    lintl = b"l_intl.nls\0"
    c1252 = b"c_1252.nls\0"
    c437 = b"c_437.nls\0"
    str_off = 0x100
    blob = bytearray(0x200)
    pos = str_off
    locs = {}
    for key, s in (("locale", locale), ("lintl", lintl), ("c1252", c1252), ("c437", c437)):
        locs[key] = cave_vma + pos
        blob[pos : pos + len(s)] = s
        pos += len(s)

    # helper(x0=void **ptr, w1=status, x2=name or 0 for locale.nls)
    # if status==0: return 0
    # p = read_nls_file(name ?: "locale.nls")
    # if p: *ptr=p; return 0
    # return status
    helper = cave_vma
    # we'll assemble with known PCs
    h = []

    def hp() -> int:
        return helper + 4 * len(h)

    # 0: cbz w1, ret_ok
    h.append(0)  # patch
    # 4: stp x29,x30,[sp,#-32]!
    h.append(0xA9BE7BFD)
    # 8: stp x0,x1,[sp,#16]
    h.append(0xA90107E0)
    # 12: cbnz x2, have_name
    h.append(0)  # patch
    # 16: adr x0, locale
    h.append(encode_adr(0, hp(), locs["locale"]))
    # 20: b do_read
    h.append(0)  # patch
    # 24: have_name: mov x0, x2
    have_name = hp()
    h.append(0xAA0203E0)
    # 28: do_read: bl read_nls_file
    do_read = hp()
    h.append(encode_bl(hp(), read_nls))
    # 32: ldp x2,x1,[sp,#16]   // ptr, status
    h.append(0xA94107E2)
    # 36: cbz x0, fail
    h.append(0)  # patch
    # 40: str x0, [x2]
    h.append(0xF9000040)
    # 44: mov w1, wzr
    h.append(0x2A1F03E1)
    # 48: fail: mov w0, w1
    fail = hp()
    h.append(0x2A0103E0)
    # 52: ldp x29,x30,[sp],#32
    h.append(0xA8C27BFD)
    # 56: ret
    h.append(0xD65F03C0)
    # 60: ret_ok: mov w0, wzr
    ret_ok = hp()
    h.append(0x2A1F03E0)
    # 64: ret
    h.append(0xD65F03C0)

    # patch forward refs
    # cbz w1, ret_ok at helper+0
    h[0] = encode_cbz_w(1, helper, ret_ok)
    # cbnz x2, have_name at helper+12
    cbnz_pc = helper + 12
    imm = (have_name - cbnz_pc) >> 2
    h[3] = 0xB5000000 | ((imm & 0x7FFFF) << 5) | 2
    # b do_read at helper+20
    h[5] = encode_b(helper + 20, do_read)
    # cbz x0, fail at helper+36
    h[9] = encode_cbz_x(0, helper + 36, fail)

    for i, w in enumerate(h):
        struct.pack_into("<I", blob, i * 4, w)

    # multi-name wrapper for NtGetNlsSectionPtr: try 3 names
    wrap = helper + 0x50
    wpc = wrap
    w = []

    def wp() -> int:
        return wrap + 4 * len(w)

    # stp x29,x30,[sp,#-48]!
    w.append(0xA9BD7BFD)
    # stp x20,x21,[sp,#16]
    w.append(0xA90157F4)
    # str x22,[sp,#32]
    w.append(0xF90013F6)
    # GetNls already has x20=ptr and w21=status; do not clobber from x0/w1
    # (the call site is a 4-byte `bl wrap` after NtClose).
    w.append(0xD503201F)  # nop
    w.append(0xD503201F)  # nop
    # cbz w21, wrap_ok
    cbz_ok_idx = len(w)
    w.append(0)
    names = ("lintl", "c1252", "c437")
    try_idx = []
    for key in names:
        try_idx.append(len(w))
        # adr x0, name
        w.append(0)
        # bl read_nls
        w.append(0)
        # cbnz x0, wrap_store
        w.append(0)
    # wrap_fail: mov w0, w21
    wrap_fail = wp()
    w.append(0x2A1503E0)
    w.append(0)  # b epilogue
    # wrap_store: str x0, [x20]; mov w0, wzr
    wrap_store = wp()
    w.append(0xF9000280)
    w.append(0x2A1F03E0)
    w.append(0)  # b epilogue
    # wrap_ok: mov w0, wzr
    wrap_ok = wp()
    w.append(0x2A1F03E0)
    # epilogue
    wrap_epi = wp()
    w.append(0xF94013F6)  # ldr x22
    w.append(0xA94157F4)  # ldp x20,x21
    w.append(0xA8C37BFD)  # ldp x29,x30,[sp],#48
    w.append(0xD65F03C0)

    w[cbz_ok_idx] = encode_cbz_w(21, wrap + 4 * cbz_ok_idx, wrap_ok)
    for i, key in enumerate(names):
        idx = try_idx[i]
        pc = wrap + 4 * idx
        w[idx] = encode_adr(0, pc, locs[key])
        w[idx + 1] = encode_bl(pc + 4, read_nls)
        imm = (wrap_store - (pc + 8)) >> 2
        w[idx + 2] = 0xB5000000 | ((imm & 0x7FFFF) << 5) | 0
    fail_b = wrap + 4 * (try_idx[-1] + 4)
    # index of b epilogue after mov w0,w21
    b_fail_idx = try_idx[-1] + 4
    w[b_fail_idx] = encode_b(wrap + 4 * b_fail_idx, wrap_epi)
    b_store_idx = b_fail_idx + 3
    w[b_store_idx] = encode_b(wrap + 4 * b_store_idx, wrap_epi)

    for i, word in enumerate(w):
        struct.pack_into("<I", blob, 0x50 + i * 4, word)

    data[cave_off : cave_off + 0x200] = blob

    # --- NtInitializeNlsFiles ---
    # 0x110: mov w20, w0  -> mov w21, w0  (keep x20 = ptr)
    mov_off_vma = init + 0x110
    mov_off = vma_to_off_elf(bytes(data), mov_off_vma)
    if u32(data, mov_off) != 0x2A0003F4:
        raise RuntimeError(f"NtInitializeNlsFiles+0x110 is {u32(data, mov_off):#x}, expected mov w20,w0")
    data[mov_off : mov_off + 4] = p32(0x2A0003F5)  # mov w21, w0
    # 0x11c: mov w0, w20; b store_lcid  -> mov x0,x20; mov w1,w21; bl helper; b store
    site = init + 0x11C
    site_off = vma_to_off_elf(bytes(data), site)
    if u32(data, site_off) != 0x2A1403E0:
        raise RuntimeError(f"NtInitializeNlsFiles+0x11c is {u32(data, site_off):#x}")
    # 12 bytes of padding after the 8-byte tail (next symbol +0x130)
    store_lcid = init + 0xA8  # 0x161e8
    words = [
        0xAA1403E0,  # mov x0, x20
        0x2A1503E1,  # mov w1, w21
        0xAA1F03E2,  # mov x2, xzr  -> helper uses locale.nls
        encode_bl(site + 12, helper),
        encode_b(site + 16, store_lcid),
    ]
    write_u32s(data, site_off, words)
    notes.append(f"patched NtInitializeNlsFiles site={site:#x}")

    # --- NtGetNlsSectionPtr ---
    # Replace `mov w0, w21` before epilogue with branch to wrap, wrap returns into epilogue
    get_mov = getnls + 0x34C  # 0x15dec
    get_off = vma_to_off_elf(bytes(data), get_mov)
    if u32(data, get_off) != 0x2A1503E0:
        raise RuntimeError(f"NtGetNlsSectionPtr+0x34c is {u32(data, get_off):#x}, expected mov w0,w21")
    data[get_off : get_off + 4] = p32(encode_b(get_mov, wrap))
    # wrap returns status in w0, but epilogue expects w21 then does mov w0,w21.
    # We overwrote that mov. Epilogue now starts at +0x350 (ldp x20,x19).
    # wrap must leave status in w0 AND we need the epilogue to use w0.
    # Change first epilogue insn? It's ldp x20,x19. After wrap ret, we'd return
    # from wrap, not fall into epilogue.
    #
    # wrap is a function that rets. We branched to it with `b`, not `bl`, so
    # wrap's ret returns to *GetNls's caller* — correct if wrap restores
    # GetNls's frame. It does not; it has its own frame and then rets to
    # GetNls's caller with GetNls's callee-saves still on GetNls's stack.
    # That's a bug. Use `bl wrap` then fall into original epilogue.
    #
    # Only 4 bytes at 0x15dec. Use: bl wrap (returns w0=status); then
    # original ldp sequence, but original next is ldp not `mov w0,w21`.
    # After our overwrite, flow is:
    #   bl wrap
    #   ldp x20,x19
    #   ldp x22,x21
    #   ldr x23
    #   ldp x29,x30
    #   add sp
    #   ret
    # wrap returns status in w0, which is what the original `mov w0,w21` did.
    # Perfect — but `b wrap` must be `bl wrap`.
    data[get_off : get_off + 4] = p32(encode_bl(get_mov, wrap))
    notes.append(f"patched NtGetNlsSectionPtr site={get_mov:#x} -> wrap={wrap:#x}")
    return notes


def backup(path: Path) -> Path:
    bak = path.with_name(path.name + ".pre-nlsfallback")
    if not bak.exists():
        shutil.copy2(path, bak)
    return bak


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("unix", type=Path)
    args = ap.parse_args()

    unix = bytearray(args.unix.read_bytes())
    notes = patch_unix(unix)
    backup(args.unix)
    args.unix.chmod(args.unix.stat().st_mode | 0o200)
    args.unix.write_bytes(unix)
    print("NLS fallback patched")
    for line in notes:
        print(line)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
