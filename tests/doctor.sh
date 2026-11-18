#!/usr/bin/env bash
# doctor.sh: the imagegen doctor (skills/imagegen/doctor.sh) and its SessionStart hook (hooks/session-start.sh), with a
# PATH of symlinks to the system tools they use plus fake codex, magick and python3, so nothing real is installed or called.
# Covers: no codex (FAIL, install command, exit 1), a codex that hangs (slow, in time), no Pillow (venv fix, --python exits 1;
# a python that has it is printed), no ImageMagick (warn, exit 0), --fix without a terminal (changes nothing), and the hook
# (silent when all pass, marker written, second run does nothing, a failing version reports again).
# Runs offline, writes only under a temp folder. Usage: tests/doctor.sh
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
D=$here/skills/imagegen/doctor.sh H=$here/hooks/session-start.sh
t=$(cd "$(mktemp -d)" && pwd -P); trap 'rm -rf "$t"' EXIT
pass=0 fail=0
ok()  { pass=$((pass + 1)); echo "  ok    $*"; }
bad() { fail=$((fail + 1)); echo "  FAIL  $*"; }

mkdir -p "$t/sys" "$t/home"
for c in bash sed grep head cat mkdir mktemp rm sleep tr dirname uname touch timeout gtimeout; do
  p=$(command -v "$c" 2>/dev/null) && [ -x "$p" ] && ln -s "$p" "$t/sys/$c"
done
# env VAR: a fresh PATH folder $t/p-<name> holding the system links; add fakes with fake <folder> <name> <body>
newpath() { rm -rf "$t/p-$1"; mkdir -p "$t/p-$1"; ln -s "$t"/sys/* "$t/p-$1/"; }
# fake removes the destination first, so a link (symbolic or hard) is replaced and never written through
fake() { rm -f "$t/p-$1/$2"; printf '#!/bin/sh\n%s\n' "$3" > "$t/p-$1/$2"; chmod +x "$t/p-$1/$2"; }
run() { local p=$1; shift; out=$(env -i HOME="$t/home" PATH="$t/p-$p" IMAGEGEN_DOCTOR_TIMEOUT=2 /bin/bash "$@" 2>&1 </dev/null); rc=$?; }

echo "== 1: no codex"
newpath nocodex; fake nocodex python3 'exit 0'; fake nocodex magick 'exit 0'
run nocodex "$D"
[ "$rc" = 1 ] && grep -q 'FAIL.*codex.*fix: .*\(brew install --cask codex\|npm i -g @openai/codex\)' <<<"$out" \
  && ok "no codex: exit 1, FAIL with the install command" || bad "no codex: exit $rc: $out"

echo "== 2: codex that hangs, and one that works"
newpath hang; fake hang codex 'sleep 30'; fake hang python3 'exit 0'; fake hang magick 'exit 0'
s=$SECONDS; run hang "$D"; e=$((SECONDS - s))
[ "$rc" = 1 ] && grep -q '^slow .*codex did not answer in 2 s' <<<"$out" && [ "$e" -lt 25 ] \
  && ok "a hanging codex is reported slow after the timeout (${e}s), not waited on" || bad "hang: exit $rc after ${e}s: $out"
newpath good; fake good codex 'exit 0'; fake good python3 'exit 0'; fake good magick 'exit 0'
run good "$D"
[ "$rc" = 0 ] && grep -q 'imagegen doctor: ok' <<<"$out" && ok "everything present: exit 0" || bad "all good: exit $rc: $out"
newpath loggedout; fake loggedout codex 'exit 1'; fake loggedout python3 'exit 0'; fake loggedout magick 'exit 0'
run loggedout "$D"
[ "$rc" = 1 ] && grep -q 'FAIL.*not logged in.*codex login' <<<"$out" && ok "logged out: FAIL, login left to the user" || bad "logged out: exit $rc: $out"

echo "== 3: no Pillow, then Pillow"
newpath nopil; fake nopil codex 'exit 0'; fake nopil magick 'exit 0'; fake nopil python3 'exit 1'
run nopil "$D"
[ "$rc" = 1 ] && grep -q "FAIL.*pillow.*box mode won't run.*python3 -m venv .*imagegen/venv && .*pip install pillow" <<<"$out" \
  && ok "no Pillow: FAIL with the venv fix, exit 1" || bad "no pillow: exit $rc: $out"
run nopil "$D" --python
[ "$rc" = 1 ] && [ -z "$out" ] && ok "--python exits 1 and prints nothing without Pillow" || bad "--python without pillow: exit $rc: $out"
run good "$D" --python
[ "$rc" = 0 ] && [ "$out" = "$t/p-good/python3" ] && ok "--python prints the python that imports PIL" || bad "--python: exit $rc: $out"
mkdir -p "$t/home/.local/share/imagegen/venv/bin"; printf '#!/bin/sh\nexit 0\n' > "$t/home/.local/share/imagegen/venv/bin/python"
chmod +x "$t/home/.local/share/imagegen/venv/bin/python"
run nopil "$D" --python
[ "$rc" = 0 ] && [ "$out" = "$t/home/.local/share/imagegen/venv/bin/python" ] && ok "--python falls back to the imagegen venv" || bad "--python venv: exit $rc: $out"
rm -rf "$t/home/.local"

echo "== 4: no ImageMagick"
newpath nomagick; fake nomagick codex 'exit 0'; fake nomagick python3 'exit 0'
run nomagick "$D"
[ "$rc" = 0 ] && grep -q '^warn .*imagemagick' <<<"$out" && ! grep -q '^FAIL' <<<"$out" && ok "ImageMagick warn, but the exit stays 0 when codex and Pillow pass" || bad "no magick: exit $rc: $out"
fake nomagick convert 'exit 0'
run nomagick "$D"
grep -q '^ok .*imagemagick' <<<"$out" && ok "convert counts as ImageMagick" || bad "convert: $out"

echo "== --quick, --fix and usage"
printf '#!/bin/sh\necho called >> %s/codex-called\n' "$t" > "$t/p-nopil/codex"
run nopil "$D" --quick
[ ! -e "$t/codex-called" ] && ! grep -q codex <<<"$out" && ok "--quick makes no codex call" || bad "--quick called codex: $out"
fake nopil python3 'exit 1'; printf '#!/bin/sh\necho ran >> %s/pip-ran\n' "$t" > "$t/p-nopil/pip"; chmod +x "$t/p-nopil/pip"
run nopil "$D" --fix
[ ! -e "$t/pip-ran" ] && grep -q 'no terminal to ask at; not run: python3 -m venv' <<<"$out" && ok "--fix with no terminal prints the command and runs nothing" || bad "--fix no tty: $out"
run nopil "$D" --bogus; [ "$rc" = 64 ] && ok "bad option: exit 64" || bad "bad option: exit $rc"
run nopil "$D" --yes;   [ "$rc" = 64 ] && ok "--yes without --fix: exit 64" || bad "--yes alone: exit $rc"

echo "== 5: the hook"
hook() { out=$(env -i HOME="$t/home" PATH="$t/p-$1" CLAUDE_PLUGIN_ROOT="$here" /bin/bash "$H" 2>&1 </dev/null); rc=$?; }
v=$(sed -n 's/.*"version"[^"]*"\([^"]*\)".*/\1/p' "$here/.claude-plugin/plugin.json" | head -n 1)
M=$t/home/.cache/imagegen/doctor-$v
hook good
[ "$rc" = 0 ] && [ -z "$out" ] && [ -e "$M" ] && ok "all pass: silent, exit 0, marker written" || bad "hook pass: exit $rc, marker $([ -e "$M" ] && echo yes || echo no): $out"
hook nopil
[ "$rc" = 0 ] && [ -z "$out" ] && ok "second run for one version does nothing (marker present)" || bad "second run: exit $rc: $out"
rm -f "$M"
hook nopil
[ "$rc" = 0 ] && [ "$(wc -l <<<"$out")" -eq 1 ] && grep -q '^imagegen doctor: pillow missing; run skills/imagegen/doctor.sh for fixes$' <<<"$out" && [ ! -e "$M" ] \
  && ok "Pillow missing: one line, no marker, exit 0" || bad "hook fail: exit $rc: $out"
hook nopil
grep -q 'pillow missing' <<<"$out" && ok "a failing version reports again at the next session start" || bad "hook fail again: $out"
rm -f "$M"
newpath nomagick2; fake nomagick2 codex 'exit 0'; fake nomagick2 python3 'exit 0'
hook nomagick2
[ "$rc" = 0 ] && grep -q '^imagegen doctor: imagemagick (recommended) missing; run skills/imagegen/doctor.sh for fixes$' <<<"$out" && [ -e "$M" ] \
  && ok "ImageMagick missing: the hook still names it, marked recommended, and the required checks leave a marker" || bad "hook nomagick: exit $rc: $out"
newpath slowpy; fake slowpy python3 'sleep 30'; rm -f "$M"
s=$SECONDS; hook slowpy; e=$((SECONDS - s))
[ "$rc" = 0 ] && [ "$e" -le 2 ] && ok "a hung python: hook still exits 0 within 2 s (${e}s)" || bad "slow python: exit $rc after ${e}s: $out"
env -i HOME="$t/home" PATH="$t/p-good" CLAUDE_PLUGIN_ROOT="$t/nowhere" /bin/bash "$H" >/dev/null 2>&1; [ $? = 0 ] && ok "a broken plugin root: still exit 0" || bad "broken root"

echo "== 6: fake never writes through a link"
newpath lnk; printf 'real tool\n' > "$t/real-tool"; chmod 755 "$t/real-tool"; sum=$(cksum < "$t/real-tool")
ln -s "$t/real-tool" "$t/p-lnk/codex"; ln "$t/real-tool" "$t/p-lnk/magick"
fake lnk codex 'exit 0'; fake lnk magick 'exit 0'
[ "$(cksum < "$t/real-tool")" = "$sum" ] && [ "$(cat "$t/real-tool")" = "real tool" ] && [ "$(stat -c %a "$t/real-tool" 2>/dev/null || stat -f %Lp "$t/real-tool")" = 755 ] \
  && ok "the file a link pointed at is unchanged after fake writes" || bad "fake wrote through a link: $(cat "$t/real-tool")"
[ -f "$t/p-lnk/codex" ] && [ ! -L "$t/p-lnk/codex" ] && [ -f "$t/p-lnk/magick" ] && [ "$(stat -c %h "$t/p-lnk/magick" 2>/dev/null || stat -f %l "$t/p-lnk/magick")" = 1 ] \
  && grep -q 'exit 0' "$t/p-lnk/codex" && ok "a symlinked and a hard-linked destination each become a regular file holding the fake" || bad "destination still a link or not written"

echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
