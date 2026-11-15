# imagegen changelog

## 0.2.0 (2026-11-15)

- **`composite.py` pastes an edit's changed region back onto the original.** `--box X,Y,W,H` names the region (the default), `--auto` finds it for flat art, and the feather falls inside the box, so every pixel outside it stays the original's when the output is PNG or WebP. The guarantee is for 8-bit RGB and RGBA originals.
- **Edit prompts say what to keep and what to change.** An edit redraws the whole picture, so the skill asks for the region, the depth position and the size back, and for two places as two edits.
- **WebP is saved lossless and JPEG output gets a warning**, since a lossy save would undo the pixel-exact paste.
- **A capacity error no longer loses the image.** The skill says how to recover it.
- **`tests/box-guarantee.sh` pins the `--box` promise** for RGB and RGBA, PNG and WebP, with Pillow (it needs a Python with Pillow, found the way `doctor.sh --python` finds it).
- **`doctor.sh` checks what imagegen needs and says how to fix it.** It looks at Codex (installed, logged in, answering), ImageMagick and a Python with Pillow, prints one line each with the fix, and `--fix` offers the ones that need no sudo or login. `--python` prints the Python that has Pillow, so composite.py runs under it. A SessionStart hook runs the quick check once per installed version and says so only when something is missing.
- **Every image keeps its recipe.** The skill writes `<name>.recipe.md` beside each image it saves: the prompt, each input with its sha256, the box and command for a paste-back, and the parent's recipe for an edit.
