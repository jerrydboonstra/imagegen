#!/usr/bin/env python3
"""Paste the changed part of an edited image back onto the original, so everything else stays pixel-exact.

An image edit redraws the whole picture: the part you asked to change is new, and every other pixel drifts a
little. This takes the original, the edit and the region that was meant to change, and writes the original with
only that region replaced.

  composite.py ORIGINAL EDIT OUT --box X,Y,W,H [--feather N]
  composite.py ORIGINAL EDIT OUT --auto [--threshold T] [--pad P] [--feather N]

--box names the region in the original's pixels. --auto finds it: the pixels where the edit differs from the
original by more than T (0-255, default 40, on the largest channel difference), grown by P pixels (default 16).
The drift an edit leaves everywhere else is usually well under 40, so it falls below the threshold.
--feather softens the region's edge over N pixels (default 4), so the seam doesn't show. The feather falls
inside the region: every pixel outside it stays exactly the original's, as long as OUT is PNG or WebP
(saved lossless) and the original is 8-bit RGB or RGBA: the original is converted to RGBA, so a palette,
grayscale or 16-bit original is converted first. JPEG is lossy, so it gets a warning.
The edit is resized to the original's size first, since it often comes back at a different one.
Prints the region it used. Needs Pillow: run doctor.sh --fix, and run this with the Python doctor.sh --python prints.
"""
import argparse
import sys

try:
    from PIL import Image, ImageChops, ImageFilter
except ImportError:
    sys.exit("composite.py needs Pillow: run skills/imagegen/doctor.sh --fix, then run this with the Python doctor.sh --python prints")


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    ap.add_argument("original")
    ap.add_argument("edit")
    ap.add_argument("out")
    how = ap.add_mutually_exclusive_group(required=True)
    how.add_argument("--box", help="X,Y,W,H in the original's pixels")
    how.add_argument("--auto", action="store_true", help="find the changed region")
    ap.add_argument("--threshold", type=int, default=40)
    ap.add_argument("--pad", type=int, default=16)
    ap.add_argument("--feather", type=int, default=4)
    a = ap.parse_args()

    orig = Image.open(a.original).convert("RGBA")
    edit = Image.open(a.edit).convert("RGBA")
    if edit.size != orig.size:
        edit = edit.resize(orig.size, Image.LANCZOS)

    if a.box:
        try:
            x, y, w, h = (int(v) for v in a.box.split(","))
        except ValueError:
            sys.exit("--box takes X,Y,W,H, four integers")
        box = (max(0, x), max(0, y), min(orig.width, x + w), min(orig.height, y + h))
    else:
        diff = ImageChops.difference(orig.convert("RGB"), edit.convert("RGB"))
        # the largest channel difference per pixel, then keep only what clears the threshold
        r, g, b = diff.split()
        mx = ImageChops.lighter(ImageChops.lighter(r, g), b)
        found = mx.point(lambda v: 255 if v > a.threshold else 0).getbbox()
        if not found:
            sys.exit(f"no pixel differs by more than {a.threshold}; lower --threshold or pass --box")
        x0, y0, x1, y1 = found
        box = (max(0, x0 - a.pad), max(0, y0 - a.pad), min(orig.width, x1 + a.pad), min(orig.height, y1 + a.pad))

    if box[2] <= box[0] or box[3] <= box[1]:
        sys.exit(f"the region {box} is empty")
    mask = Image.new("L", orig.size, 0)
    mask.paste(255, box)
    if a.feather > 0:
        # blur, then clip to the region, so the blend stays inside it and nothing outside changes
        soft = mask.filter(ImageFilter.GaussianBlur(a.feather))
        mask = Image.new("L", orig.size, 0)
        mask.paste(soft.crop(box), box[:2])
    out = Image.composite(edit, orig, mask)
    ext = a.out.lower().rsplit(".", 1)[-1]
    if ext in ("jpg", "jpeg"):
        out = out.convert("RGB")
        print("warning: JPEG is lossy, so pixels outside the region won't stay exact; write PNG or WebP", file=sys.stderr)
    # WebP defaults to lossy in Pillow, which would undo the pixel-exact paste
    out.save(a.out, **({"lossless": True} if ext == "webp" else {}))
    x0, y0, x1, y1 = box
    print(f"pasted region x={x0} y={y0} w={x1 - x0} h={y1 - y0} into {a.out}")


if __name__ == "__main__":
    main()
