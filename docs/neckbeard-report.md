# 🔍 imagegen 0.2.4 · what it adds

`2026-11-17` · neckbeard 1.17.7 · [jerrydboonstra/imagegen](https://github.com/jerrydboonstra/imagegen) 0.2.4 @ `imagegen-v0.2.4`

## What it adds

### Injects
- Skills:
  - imagegen: description every session (485 chars); the file on demand (11786 bytes, ~2946 tokens)
- Rule files: none
- Hook-injected text:
  - hooks/session-start.sh (SessionStart, built at run time, at least 66 bytes): imagegen doctor: … missing; run skills/imagegen/doctor.sh for fixes
  writes: mkdir -p …; : > …
  - built at run time: read from the script's own text, not run; commands it runs are not followed and may print or write files

### Hooks
- Hooks:
  - SessionStart: hooks/session-start.sh
  - reaches subagents: false (no event known to fire in a subagent)

### Subagents and commands
- Agents: none
- Commands: none

### State it may leave
- Persistence candidates:
  - hooks/session-start.sh
  - skills/imagegen/doctor.sh

### Reaches outside the session
- MCP servers: none

### Source
- Kind: plugin
- Name: imagegen (from plugin.json)
- Version: 0.2.4 (from plugin.json)
- plugin.json:
  - name and version, shown above
- Marketplace: not applicable
- Commit: imagegen-v0.2.4

Load timing is how Claude Code loads skills, not measured here. Tokens are estimated as bytes / 4; where the inventory fell back to a character count, "bytes" counts characters.

No reader's rules were read: this report lists facts only and carries no verdict.
