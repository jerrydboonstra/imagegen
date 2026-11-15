#!/usr/bin/env bash
# box-guarantee.sh: composite.py's promise with --box, that every pixel outside the box stays exactly the original's, for an
# 8-bit RGB original and for an RGBA original with varying alpha, with the default feather and with a wide one, saved as PNG and
# as lossless WebP. Also that the box itself changes (so the test could fail), and that a box past the image's edge is clipped.
# COMPOSITE=<path> runs another copy of composite.py, which is how a mutant is tried. Needs a Python with Pillow, found the way doctor.sh --python finds it; FAILs (exit 1) when there is none.
# Runs offline. Usage: tests/box-guarantee.sh
set -uo pipefail
here=$(cd "$(dirname "$0")/.." && pwd)
COMPOSITE=${COMPOSITE:-$here/skills/imagegen/composite.py}
# the Python with Pillow, as the skill finds it: doctor.sh --python (by path), else python3 if it imports PIL
py=$("$here/skills/imagegen/doctor.sh" --python 2>/dev/null) && [ -n "$py" ] || { py=python3; command -v python3 >/dev/null 2>&1 && python3 -c 'import PIL' 2>/dev/null || py=; }
[ -n "$py" ] || { echo "  FAIL  no Python with Pillow: run doctor.sh --fix"; exit 1; }
t=$(cd "$(mktemp -d)" && pwd -P); trap 'rm -rf "$t"' EXIT
pass=0 fail=0
ok()  { pass=$((pass + 1)); echo "  ok    $*"; }
bad() { fail=$((fail + 1)); echo "  FAIL  $*"; }

# make MODE: an original and an edit of it, 48x36, every pixel different between them
"$py" - "$t" <<'PY'
import sys
from PIL import Image
t = sys.argv[1]
w, h = 48, 36
for mode in ("RGB", "RGBA"):
    o, e = Image.new(mode, (w, h)), Image.new(mode, (w, h))
    for x in range(w):
        for y in range(h):
            a = 255 if mode == "RGB" else 40 + (x * 5 + y * 3) % 200
            o.putpixel((x, y), ((x * 5) % 256, (y * 7) % 256, (x * y) % 256) + (() if mode == "RGB" else (a,)))
            e.putpixel((x, y), ((x * 5 + 90) % 256, (y * 7 + 60) % 256, (x * y + 120) % 256) + (() if mode == "RGB" else (255 - a,)))
    o.save(f"{t}/orig-{mode}.png"); e.save(f"{t}/edit-{mode}.png")
PY

# check MODE EXT FEATHER BOX: run composite.py, then count pixels outside the box that differ from the original's and
# pixels inside it that differ from the original's
check() {
  local mode=$1 ext=$2 feather=$3 box=$4 out=$t/out-$1-$3.$2 res
  "$py" "$COMPOSITE" "$t/orig-$mode.png" "$t/edit-$mode.png" "$out" --box="$box" --feather "$feather" >/dev/null 2>&1 \
    || { bad "$mode $ext feather $feather: composite.py failed"; return; }
  res=$("$py" - "$t/orig-$mode.png" "$out" "$box" <<'PY'
import sys
from PIL import Image
o = Image.open(sys.argv[1]).convert("RGBA"); r = Image.open(sys.argv[2]).convert("RGBA")
x, y, w, h = (int(v) for v in sys.argv[3].split(","))
x1, y1 = min(o.width, x + w), min(o.height, y + h)
outside = inside = 0
for px in range(o.width):
    for py in range(o.height):
        same = o.getpixel((px, py)) == r.getpixel((px, py))
        if x <= px < x1 and y <= py < y1:
            inside += not same
        else:
            outside += not same
print(outside, inside)
PY
  )
  set -- $res
  [ "${1:-x}" = 0 ] && [ "${2:-0}" -gt 0 ] && ok "$mode $ext feather $feather, box $box: 0 pixels outside changed, $2 inside changed" \
    || bad "$mode $ext feather $feather, box $box: outside changed ${1:-?}, inside changed ${2:-?}"
}

echo "== pixels outside --box stay the original's"
for mode in RGB RGBA; do
  check "$mode" png 4 "10,8,20,14"
  check "$mode" png 12 "10,8,20,14"
  check "$mode" webp 4 "10,8,20,14"
  check "$mode" png 0 "10,8,20,14"
done
echo "== a box past the image's edge is clipped, and still leaves the rest alone"
check RGB png 4 "30,20,100,100"
check RGBA png 4 "-5,-5,20,15"

echo
echo "$pass passed, $fail failed"
[ "$fail" = 0 ]
