---
name: imagegen
description: "Generate or edit images (logos, icons, social cards, illustrations, mockups) from the command line through Codex CLI's built-in $imagegen skill, which runs OpenAI's GPT Image model on the user's ChatGPT login. Use whenever a task needs a new raster image or a variation or edit of one, instead of asking the user to paste prompts into ChatGPT. Triggers: \"generate an image\", \"make a logo\", \"draw\", \"render a mockup\", \"try a logo round\", \"make an icon\", \"edit this image\"."
---

# Image generation through Codex CLI

`codex exec` can call Codex CLI's built-in `$imagegen` skill, which writes a PNG. With Codex logged in to a ChatGPT account, a session can run image rounds itself instead of handing prompts to the user to paste into ChatGPT and waiting for screenshots back.

## Before the first image

Check that it can work at all:

```bash
bash "${CLAUDE_PLUGIN_ROOT}/skills/imagegen/doctor.sh"
```

It checks Codex (installed, logged in, answering within 20 seconds), ImageMagick and a Python with Pillow, prints one line each with the fix for any that fails, and exits 1 when something required is missing. To install what it can (a Pillow venv, brew installs; never sudo, never `codex login`), ask the user first, then run `doctor.sh --fix --yes`; at a terminal, `doctor.sh --fix` asks for each one itself.

- **No `codex`, or not logged in:** don't generate anything and don't try another provider on your own. Tell the user what's missing (`codex login` is theirs to run), and fall back to what needs no generator: draw it as SVG by hand when the job allows (an icon, a logo sketch, a diagram), or hand over the written prompt so they can run it elsewhere. A caller that depends on this skill should expect that fallback.
- Never handle the credential file (`~/.codex/auth.json`) yourself.

## Run it

Work in a folder of its own (a scratch directory, or the project's own folder for rounds), since Codex writes into its working directory:

```bash
cd <out-dir> && timeout 300 codex exec -s workspace-write --skip-git-repo-check -- \
  'Use the $imagegen image generation tool to <the whole prompt>. Save it as ./<name>.png. Reply with the file path only.' </dev/null
```

Keep the `--` and the `</dev/null`: `--` ends the options, so nothing before it can swallow the prompt, and `</dev/null` stops a background run from waiting on stdin.

Write the image's recipe once it is saved ("Keep a recipe for every image", below).

- **Edit or vary an image:** add `-i <input.png>` before the `--`, and say what to keep and what to change: "Keep this exact image. Change only …". `-i` takes several files, so without the `--` it takes the prompt as one more file and Codex says "No prompt provided via stdin" (seen on codex-cli 0.160).
- **An edit redraws the whole image; it doesn't patch it.** Expect changes everywhere, including the background: on a recoloured leaf of a stippled pear, 98.8% of the pixels outside the box around the leaf differed (RMS error about 10 of 255, about 4%); on flat art most pixels still changed, by less (RMS error about 1%) (measured with codex-cli 0.160). A background went from #F7F6F1 to #FAF9F4. Edits are slower too: two parallel edits of 1254 px images, each with a long prompt, took about two minutes. The size changes as well: a 64 px input came back at 1254 px. See "Changing one part of an image" below.
- **Codex may skip the generator for a small edit.** Asked to add a plain shape, it has drawn it with ImageMagick instead, keeping the input's pixels and size. Either result can be right; check the output's size and look at it, and say "use the image_gen tool" in the prompt when you need a generated image.
- **Several at once:** ask for each file by name in one prompt ("save each to ./r1-<n>.png"), or run separate calls in parallel for independent prompts.
- **Size:** say it in the prompt (square 1:1, or 1280x640 for a social card). "Square" has come back at 1254x1254; crop or resize afterwards (Pillow, `sips`, ImageMagick) when an exact size matters.
- One image takes about a minute. Use `timeout 300` and run long batches in the background.
- **If `codex exec` fails after generating** ("Selected model is at capacity" is OpenAI's servers, not your credits), the image may already exist: Codex keeps every generated image under `~/.codex/generated_images/<session>/`. Look there for one written during the run before you run it again.

## Changing one part of an image

Work in steps, one change per edit, each from the last good image. If a change touches two places, make it two edits and paste each back before the next, since the drift is per edit. Two things keep the rest of the picture where it was.

**Say what to keep, then what to change.** Use this shape for every edit prompt:

```
Keep exactly: <A>, <B>, <C>.
Change only: <D>.
```

Name each thing to keep so it can't be misread: colours as hex (`background #F7F6F1`), positions in plain words or fractions (`the cat sits in the lower third, centred`), any text in quotes, letter for letter (`the word "Herder" in the same font and size`), and the style (`flat vector, no gradients`). In a scene with depth, name a thing by what it is and its place in the arrangement, never by left or right alone (`the front cat, the one in 3D glasses`, `the second box back`), since a redraw can mirror the scene; and add a keep line for the composition itself: `same camera, same framing, every object in its place and size`. List what matters most first. Ask for one change per edit; two changes in one prompt drift more than two edits do.

**Paste the change back onto the original.** The prompt holds the composition, not the pixels. On textured art (stippling, grain, photos) no keep list holds the texture, and the redraw changes it everywhere (98.8% of the pixels outside the box around the changed leaf, on a stippled pear), so the paste-back is the only guarantee: choose the box before you prompt. Ask for the original's size back too (`return at 640x640`), though Codex often ignores it (a 640 px input came back at 1254 px). When the rest must stay exact (a brand colour, a background that has to match a page, an image already approved), take only the changed part from the edit and put it on the original:

```bash
"$(bash "${CLAUDE_PLUGIN_ROOT}/skills/imagegen/doctor.sh" --python)" "${CLAUDE_PLUGIN_ROOT}/skills/imagegen/composite.py" original.png edit.png result.png --box=X,Y,W,H
"$(bash "${CLAUDE_PLUGIN_ROOT}/skills/imagegen/doctor.sh" --python)" "${CLAUDE_PLUGIN_ROOT}/skills/imagegen/composite.py" original.png edit.png result.png --auto
```

`--box` names the region yourself, in the original's pixels: use it by default, written `--box=` so a negative X or Y still parses. `--auto` finds the region where the edit differs by more than the drift (`--threshold`, default 40 of 255), plus a margin, and suits flat art only: on textured art (stippling, photos, grain) the redraw moves the texture everywhere, and `--auto` takes most of the picture. Tried on a 640 px stippled logo, `--auto` took 559x500 px, while a 170x100 box around the one change left every other pixel identical to the original. In either mode, composite.py scales the edit to the original's size first, so `--box` always means the same pixels in both, and feathers the seam inside the region, so every pixel outside it stays the original's. Write the result as PNG or WebP (saved lossless); JPEG is lossy, so it can't stay exact, and composite.py warns. It needs Pillow: `doctor.sh --python` prints a Python that has it, and `doctor.sh --fix` makes a venv with it when none does. Look at the result: if the changed part bleeds past the box (a shadow, a reflection), widen it.

## Keep a recipe for every image

Every image you save (a generated one, an edit, a box-mode result) gets a recipe file beside it: `<name>.recipe.md` next to `<name>.png`. Write it in the same step as the save, from what you actually ran, not from memory afterwards. It records how the image was made so a person, or a later session, can make another like it. The model draws something different on every run, so a recipe never promises the same pixels.

Use this shape exactly. The header block is fixed; the prompt follows it in full, as sent to Codex:

```markdown
# Recipe: <name>.png

- image: <name>.png
- kind: generate | edit | box paste-back
- made: <YYYY-MM-DD> with codex-cli <version from `codex --version`>   (a paste-back: the date only, then `with composite.py`)
- parent: <path to the parent image's .recipe.md>   (edits and paste-backs; `none` for a first image or when the parent has no recipe)
- inputs:
  - <path to input image> sha256 <hash>   (one line per `-i` file; `none` when there are none)
- box: X,Y,W,H   (box mode only; with --auto, the region composite.py printed)
- composite: <the composite.py command, with these relative paths>   (box mode only; otherwise omit both)

## Prompt

<the whole prompt, exactly as sent to Codex>   (a paste-back sends none: write `none: made by composite.py from the inputs above; the prompt is in the parent's recipe`)
```

- **Paths are relative to the recipe file**, never a home-directory path. Take each hash with `shasum -a 256 <file>` (Mac) or `sha256sum <file>` (Linux): it lets a later reader tell whether an input is still the same file.
- **An edit's recipe names its parent**: the recipe of the image it was made from, and lists that image as an input with its hash. An edit of an image with no recipe (the user's own file) says `parent: none` and still lists the image as an input. A box-mode result names the edit's recipe as its parent, lists the original and the edit as inputs, and holds the box and the command.
- **A recipe holds nothing the prompt didn't.** The rule against secrets, private names and personal data in a prompt covers it.
- **To make another like it, read the recipe and nothing else:** check each input's hash, run the same prompt with the same `-i` inputs, and save the result under a new name with its own recipe whose parent is the old one. The recorded prompt ends with its own save line ("Save it as ./pear.png."), and sent as written it overwrites the original. Before you run it, replace the file name in that save line with the new image's name ("./pear-2.png") and change no other word. The new recipe records the prompt as sent, with the new name. A rerun never writes to the original's name. For a paste-back recipe, which holds no prompt, rerun its parent's recipe (a new edit), then run the composite command with the new edit in place of the old one and the box unchanged. If an input's hash differs, say so before going on.

## Then look at it

Read every PNG you generate before you report it. Judge it against the brief yourself: text rendered wrong, extra objects, the wrong style. Show the user only the ones worth their time, and name the file paths.

## Rules

- **It spends the user's ChatGPT plan.** A round of a few images is fine without asking. Ask before a batch of more than about ten, or before looping until something passes.
- **Nothing generated goes public without the user's OK:** not into a public repo, a README, a social card or a post.
- **Prompts follow the project's brand rules.** No copyrighted characters or trademarks, and respect any words the project keeps private. Keep brand prompts and results in that project's brand folder, with each image's recipe beside it.
- **Never paste a secret, private name or personal data into a prompt.** It goes to OpenAI.
- **A headless machine** may refuse Codex's device-code login unless it's enabled in ChatGPT's security settings. Log in through a port forward instead: `ssh -t -L 1455:localhost:1455 <host> 'codex login'`, then open the printed URL in a local browser.
