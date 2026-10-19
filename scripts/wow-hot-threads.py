#!/usr/bin/env python3
"""Find the busiest threads of a Wine process and backtrace them via ptrace
(PTRACE_SEIZE/INTERRUPT + GETREGSET + fp-chain walk over /proc/pid/mem).

usage: wow-hot-threads.py [pid] [top=4] [samples=3]
"""

from __future__ import annotations

import ctypes
import ctypes.util
import os
import struct
import sys
import time

PTRACE_DETACH = 17
PTRACE_GETREGSET = 0x4204
PTRACE_SEIZE = 0x4206
PTRACE_INTERRUPT = 0x4207
NT_PRSTATUS = 1
TEB_UNIQUE_THREAD = 0x48

libc = ctypes.CDLL(ctypes.util.find_library("c"), use_errno=True)
libc.ptrace.restype = ctypes.c_long
libc.ptrace.argtypes = [ctypes.c_long, ctypes.c_long, ctypes.c_void_p, ctypes.c_void_p]


class iovec(ctypes.Structure):
    _fields_ = [("iov_base", ctypes.c_void_p), ("iov_len", ctypes.c_size_t)]


def find_pid() -> int:
    for p in os.listdir("/proc"):
        if not p.isdigit():
            continue
        try:
            cmd = open(f"/proc/{p}/cmdline", "rb").read()
        except OSError:
            continue
        if cmd.startswith(b"/root/Storage/Game") and b"WowB" in cmd:
            return int(p)
    sys.exit("no WowB process found")


def read_maps(pid):
    maps = []
    with open(f"/proc/{pid}/maps") as f:
        for line in f:
            parts = line.split(None, 5)
            lo, hi = (int(x, 16) for x in parts[0].split("-"))
            maps.append((lo, hi, parts[1], int(parts[2], 16), parts[5].strip() if len(parts) > 5 else ""))
    return maps


def fmt_loc(maps, addr):
    for lo, hi, perms, off, path in maps:
        if lo <= addr < hi:
            name = os.path.basename(path) if path else "[anon]"
            # For PE files Wine maps sections at file offset == rva for our purposes
            return f"{name}+{addr - lo + off:#x}"
    return f"{addr:#x}?"


def thread_cpu(pid):
    out = {}
    for t in os.listdir(f"/proc/{pid}/task"):
        try:
            st = open(f"/proc/{pid}/task/{t}/stat").read()
        except OSError:
            continue
        rest = st[st.rfind(")") + 2 :].split()
        out[int(t)] = int(rest[11]) + int(rest[12])  # utime+stime
    return out


def getregs(tid):
    buf = (ctypes.c_uint64 * 34)()
    iov = iovec(ctypes.addressof(buf), ctypes.sizeof(buf))
    if libc.ptrace(PTRACE_GETREGSET, tid, NT_PRSTATUS, ctypes.byref(iov)) != 0:
        return None
    return list(buf)


def sample(tid, pid, mem, maps):
    if libc.ptrace(PTRACE_SEIZE, tid, None, None) != 0:
        return f"seize failed errno={ctypes.get_errno()}"
    try:
        if libc.ptrace(PTRACE_INTERRUPT, tid, None, None) != 0:
            return f"interrupt failed errno={ctypes.get_errno()}"
        os.waitpid(tid, 0x40000000)  # __WALL
        regs = getregs(tid)
        if not regs:
            return f"getregs failed errno={ctypes.get_errno()}"
        pc, sp, fp, lr, x18 = regs[32], regs[31], regs[29], regs[30], regs[18]
        frames = [pc, lr]
        for _ in range(24):
            try:
                blk = os.pread(mem, 16, fp)
            except OSError:
                break
            if len(blk) < 16:
                break
            nfp, nlr = struct.unpack("<QQ", blk)
            if not nlr or nfp <= fp and nfp:
                if nlr:
                    frames.append(nlr)
                break
            frames.append(nlr)
            if not nfp:
                break
            fp = nfp
        try:
            wtid = struct.unpack("<Q", os.pread(mem, 8, x18 + TEB_UNIQUE_THREAD))[0]
        except OSError:
            wtid = 0
        return f"wtid={wtid:#x} sp={sp:#x}\n      " + "\n      ".join(fmt_loc(maps, a) for a in frames)
    finally:
        libc.ptrace(PTRACE_DETACH, tid, None, None)


def main():
    pid = int(sys.argv[1]) if len(sys.argv) > 1 else find_pid()
    top = int(sys.argv[2]) if len(sys.argv) > 2 else 4
    nsamp = int(sys.argv[3]) if len(sys.argv) > 3 else 3
    a = thread_cpu(pid)
    time.sleep(1.0)
    b = thread_cpu(pid)
    delta = sorted(((b.get(t, 0) - v, t) for t, v in a.items()), reverse=True)
    print(f"pid {pid} threads={len(b)}  top cpu ticks/sec: {[(t, d) for d, t in delta[:8]]}")
    maps = read_maps(pid)
    mem = os.open(f"/proc/{pid}/mem", os.O_RDONLY)
    for d, tid in delta[:top]:
        print(f"\n== tid {tid} ({d} ticks/s)")
        for i in range(nsamp):
            print(f"  [{i}] {sample(tid, pid, mem, maps)}")
            time.sleep(0.2)


if __name__ == "__main__":
    main()
