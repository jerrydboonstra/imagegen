# imagegen changelog

## 0.2.4 (2026-11-17)

- The README shows a CI badge and an MIT license badge under its title.
- **A neckbeard report says what imagegen adds to a session.** `docs/neckbeard-report.md` lists the skill, the hook and what each loads, and the README shows its badge under the title.
- The README links this changelog near the top and in the license paragraph.

## 0.2.3 (2026-11-15)

- Added a short contributing guide, a security note, issue forms and a test workflow.

## 0.2.2 (2026-11-15)

- The README no longer asks for an invite: the repo is public.

## 0.2.1 (2026-11-15)

- **The README opens with Install.** Three ways in (a prompt to paste into Claude Code, the `/plugin install ... --marketplace` line, and two shell lines), then what you need and a first prompt. The long setup is now "Set up from zero", and it says where the installed plugin's files are for running `composite.py` or the doctor by hand.
- The 0.2.0 entry about Codex's own copy now says only what was tested.

## 0.2.0 (2026-11-15)

- **`composite.py` pastes an edit's changed region back onto the original.** `--box X,Y,W,H` names the region (the default), `--auto` finds it for flat art, and the feather falls inside the box, so every pixel outside it stays the original's when the output is PNG or WebP. The guarantee is for 8-bit RGB and RGBA originals.
- **Edit prompts say what to keep and what to change.** An edit redraws the whole picture, so the skill asks for the region, the depth position and the size back, and for two places as two edits.
- **WebP is saved lossless and JPEG output gets a warning**, since a lossy save would undo the pixel-exact paste.
- **Codex keeps its own copy of each image** under `~/.codex/generated_images/<session>/`, and SKILL.md names that folder as the place to look.
- **`tests/box-guarantee.sh` pins the `--box` promise** for RGB and RGBA, PNG and WebP, with Pillow (it needs a Python with Pillow, found the way `doctor.sh --python` finds it).
- **`doctor.sh` checks what imagegen needs and says how to fix it.** It looks at Codex (installed, logged in, answering), ImageMagick and a Python with Pillow, prints one line each with the fix, and `--fix` offers the ones that need no sudo or login. `--python` prints the Python that has Pillow, so composite.py runs under it. A SessionStart hook runs the quick check once per installed version and says so only when something is missing.
- **Every image keeps its recipe.** The skill writes `<name>.recipe.md` beside each image it saves: the prompt, each input with its sha256, the box and command for a paste-back, and the parent's recipe for an edit.
