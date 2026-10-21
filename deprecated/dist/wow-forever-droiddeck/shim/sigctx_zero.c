/*
 * sigctx_zero.c - LD_PRELOAD shim for Wine (Hangover) on aarch64, two fixes
 * that WoW Forever's anti-tamper layer needs:
 *
 * 1. Zeroed exception CONTEXT.
 *    Wine's unix signal handlers (dlls/ntdll/unix/signal_arm64.c) declare
 *    `CONTEXT context;` uninitialised on the signal stack and save_context()
 *    only fills the general/FP registers.  The hardware debug registers
 *    (Bcr/Bvr/Wcr/Wvr @ 0x318..0x390) therefore contain whatever was last on
 *    the alternate signal stack.  WoW's VEH treats stale bits there as a
 *    hardware breakpoint -> "Game Initialization Failed: I" (randomly).
 *    We wrap the SA_SIGINFO handlers Wine installs for the synchronous fault
 *    signals and zero the signal stack below sp before chaining.
 *
 * 2. Syscall dispatcher reachable from a manually mapped ntdll.dll.
 *    WoW maps a clean ntdll.dll from disk and calls Nt* through it.  Wine's
 *    stubs fetch __wine_syscall_dispatcher from the PE image's .data, which is
 *    zero in such a copy.  scripts/patch-ntdll-teb-table-stub.py rewrites the
 *    stubs to `ldr x16,[x18,#0x370]; ldr x16,[x16,#8]` i.e. to read
 *    KeServiceDescriptorTable[0].CounterTable (unused by Wine).  This shim
 *    stores the dispatcher address there as soon as ntdll.so installs its
 *    first signal handler (before any PE code runs).
 *
 *    Offsets are for Hangover 11.16 (debian13 build) ntdll.so and are
 *    verified against instruction/data signatures before anything is written.
 *    Override with WINE_TEBSTUB_OFFSETS=<table_hex>:<dispatcher_hex>.
 *
 * Build (aarch64):  zig cc -target aarch64-linux-gnu -O2 -shared -fPIC \
 *                       -o libsigctx_zero.so sigctx_zero.c
 * Use:              LD_PRELOAD=/path/libsigctx_zero.so wine ...
 */
#define _GNU_SOURCE
#include <signal.h>
#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <dlfcn.h>

typedef void (*sa_fn)(int, siginfo_t *, void *);

static sa_fn real_handlers[NSIG];
static int (*real_sigaction)(int, const struct sigaction *, struct sigaction *);

/* ---------- 1. zero the signal stack below sp ---------- */

#define ZERO_BYTES   0x8000   /* plenty for CONTEXT (0x390) + handler frames */
#define GUARD_BYTES  0x1000   /* keep away from the bottom of the alt stack  */

static inline void zero_below_sp(const ucontext_t *uc)
{
    uintptr_t sp, lo, hi, start;
    __asm__ volatile("mov %0, sp" : "=r"(sp));

    lo = (uintptr_t)uc->uc_stack.ss_sp;
    hi = lo + uc->uc_stack.ss_size;
    if (!lo || sp <= lo || sp > hi) return;   /* not on the alternate stack */

    start = sp - ZERO_BYTES;
    if (start < lo + GUARD_BYTES) start = lo + GUARD_BYTES;
    if (start >= sp) return;

    for (volatile __uint128_t *p = (volatile __uint128_t *)start;
         (uintptr_t)p < sp; p++) *p = 0;
}

static void trampoline(int sig, siginfo_t *si, void *uc)
{
    zero_below_sp((const ucontext_t *)uc);
    real_handlers[sig](sig, si, uc);
}

static int wrap_signal(int sig)
{
    return sig == SIGILL || sig == SIGSEGV || sig == SIGBUS ||
           sig == SIGTRAP || sig == SIGFPE;
}

/* ---------- 2. publish __wine_syscall_dispatcher in CounterTable ---------- */

static int tebstub_done;

static void publish_dispatcher(const void *handler)
{
    Dl_info info;
    uintptr_t base, table_off = 0xa09a0, disp_off = 0x3a4e0;
    const char *env, *name;
    uint64_t *table;
    const uint32_t *disp;

    if (tebstub_done) return;
    if (!dladdr(handler, &info) || !info.dli_fname || !info.dli_fbase) return;
    name = strrchr(info.dli_fname, '/');
    name = name ? name + 1 : info.dli_fname;
    if (strcmp(name, "ntdll.so") != 0) return;   /* not Wine's unix ntdll yet */

    tebstub_done = 1;   /* one attempt per process */
    if (getenv("WINE_TEBSTUB_DISABLE")) return;
    if ((env = getenv("WINE_TEBSTUB_OFFSETS")))
    {
        char *end;
        table_off = strtoull(env, &end, 16);
        if (*end == ':') disp_off = strtoull(end + 1, NULL, 16);
    }
    base  = (uintptr_t)info.dli_fbase;
    table = (uint64_t *)(base + table_off);
    disp  = (const uint32_t *)(base + disp_off);

    /* KeServiceDescriptorTable[0]: { ServiceTable, CounterTable, ServiceLimit, ArgumentTable } */
    if (table[0] < base || table[0] > base + 0x200000 ||   /* ServiceTable in ntdll.so */
        table[1] != 0 ||                                   /* CounterTable unused */
        table[2] < 0x80 || table[2] > 0x800 ||             /* ServiceLimit plausible */
        disp[0] != 0xd503245f || disp[1] != 0xf941be4a)    /* bti c; ldr x10,[x18,#0x378] */
    {
        fprintf(stderr, "sigctx_zero: ntdll.so layout mismatch (table %#lx disp %#lx), "
                "TEB-table syscall stubs NOT enabled\n",
                (unsigned long)table_off, (unsigned long)disp_off);
        return;
    }
    table[1] = (uint64_t)(uintptr_t)disp;
    __asm__ volatile("dmb ish" ::: "memory");
}

/* ---------- interposed sigaction ---------- */

int sigaction(int sig, const struct sigaction *act, struct sigaction *oldact)
{
    if (!real_sigaction)
        real_sigaction = dlsym(RTLD_NEXT, "sigaction");

    if (act && (act->sa_flags & SA_SIGINFO) && act->sa_sigaction &&
        act->sa_sigaction != trampoline)
    {
        publish_dispatcher((const void *)act->sa_sigaction);

        if (wrap_signal(sig))
        {
            struct sigaction a = *act;
            real_handlers[sig] = act->sa_sigaction;
            a.sa_sigaction = trampoline;
            return real_sigaction(sig, &a, oldact);
        }
    }
    return real_sigaction(sig, act, oldact);
}
