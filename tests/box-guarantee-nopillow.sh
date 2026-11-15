#!/usr/bin/env bash
# box-guarantee-nopillow.sh: box-guarantee.sh must FAIL, not skip, when no Python with Pillow exists. The release's main claim
# is the box promise, so a host that can't test it can't release. Forces "no Pillow" with an empty HOME (no imagegen venv) and a
# python3 stub that has no PIL, first on PATH. Runs offline. Usage: tests/box-guarantee-nopillow.sh
set -uo pipefail
here=$(cd "$(dirname "$0")" && pwd)
t=$(cd "$(mktemp -d)" && pwd -P); trap 'rm -rf "$t"' EXIT
mkdir -p "$t/bin" "$t/home"
printf '#!/bin/sh\nexit 1\n' > "$t/bin/python3"; chmod +x "$t/bin/python3"
out=$(HOME="$t/home" PATH="$t/bin:/usr/bin:/bin" bash "$here/box-guarantee.sh" 2>&1); rc=$?
fail=0
[ "$rc" = 1 ] && echo "  ok    exits 1 with no Pillow" || { echo "  FAIL  exit was $rc, want 1"; fail=1; }
case $out in *"FAIL  no Python with Pillow: run doctor.sh --fix"*) echo "  ok    prints the FAIL line" ;; *) echo "  FAIL  no 'FAIL  no Python with Pillow' line; output: $out"; fail=1 ;; esac
[ "$fail" = 0 ] && echo "2 passed, 0 failed" || echo "FAILED"
exit "$fail"
