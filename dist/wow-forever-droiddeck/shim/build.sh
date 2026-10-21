#!/bin/bash
# Cross-compile libsigctx_zero.so for the DroidDeck guest (glibc aarch64).
# Uses zig as a hermetic cross C compiler so no aarch64 toolchain is needed
# on the host.  Tested with zig 0.17.0.
set -euo pipefail
cd "$(dirname "$0")"

ZIG="${ZIG:-zig}"
if ! command -v "$ZIG" >/dev/null 2>&1; then
  echo "zig not found; set ZIG=/path/to/zig (https://ziglang.org/download/)" >&2
  exit 1
fi

"$ZIG" cc -target aarch64-linux-gnu -O2 -shared -fPIC -Wall \
  -o libsigctx_zero.so sigctx_zero.c -ldl
ls -la libsigctx_zero.so
