#!/usr/bin/env bash
# doctor.sh: checks what the imagegen skill needs and says how to fix what is missing.
#
#   doctor.sh              check everything, change nothing
#   doctor.sh --quick      only ImageMagick and Pillow (no codex call), for the SessionStart hook
#   doctor.sh --python     print the path of a Python that has Pillow, else exit 1 (run composite.py with it)
#   doctor.sh --fix        offer each fix that needs no sudo and no login; asks "run <command>? [y/N]" at the terminal
#   doctor.sh --fix --yes  run those fixes without asking: only after the user has said yes
#
# One line per check: "ok", "FAIL", "warn" or "slow", the check, what it found and, for a FAIL or warn, "| fix: <command>".
# Exit 0 when every required check passes (Codex installed, logged in and answering; Pillow for composite.py), 1 when
# one doesn't or Codex didn't answer in time, 64 on bad usage. ImageMagick is recommended: a miss prints warn and doesn't change the exit.
# IMAGEGEN_DOCTOR_TIMEOUT (seconds, default 20) bounds each codex call; IMAGEGEN_DOCTOR_PY_TIMEOUT (default 10) bounds the
# Pillow import. Never runs sudo or `codex login`. Works with bash 3.2 and up.
set -u

quick=0 want_python=0 fix=0 yes=0
for a in "$@"; do
  case $a in
    --quick) quick=1 ;;
    --python) want_python=1 ;;
    --fix) fix=1 ;;
    --yes) yes=1 ;;
    -h|--help) sed -n '2,/^set -u/p' "$0" | sed '$d' | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "doctor.sh: unknown option $a (see doctor.sh --help)" >&2; exit 64 ;;
  esac
done
[ "$yes" = 0 ] || [ "$fix" = 1 ] || { echo "doctor.sh: --yes goes with --fix" >&2; exit 64; }
[ "$want_python" = 0 ] || [ $((quick + fix)) = 0 ] || { echo "doctor.sh: --python stands alone" >&2; exit 64; }

T=${IMAGEGEN_DOCTOR_TIMEOUT:-20}
PT=${IMAGEGEN_DOCTOR_PY_TIMEOUT:-10}
VENV=${HOME:-/nonexistent}/.local/share/imagegen/venv
tmp=$(mktemp -d 2>/dev/null) || { echo "doctor.sh: no temp folder" >&2; exit 64; }
trap 'rm -rf "$tmp"' EXIT

# run_t SECONDS COMMAND...: output to $tmp/out; status 124 when it ran past SECONDS (the command is not waited on)
run_t() {
  local secs=$1 pid w rc; shift
  : > "$tmp/out"; rm -f "$tmp/timedout"
  if command -v timeout >/dev/null 2>&1; then timeout "$secs" "$@" >"$tmp/out" 2>&1 </dev/null; return $?
  elif command -v gtimeout >/dev/null 2>&1; then gtimeout "$secs" "$@" >"$tmp/out" 2>&1 </dev/null; return $?; fi
  "$@" >"$tmp/out" 2>&1 </dev/null & pid=$!
  ( sleep "$secs"; : > "$tmp/timedout"; kill "$pid" 2>/dev/null ) >/dev/null 2>&1 & w=$!
  wait "$pid" 2>/dev/null; rc=$?
  kill "$w" 2>/dev/null; wait "$w" 2>/dev/null
  [ -f "$tmp/timedout" ] && return 124
  return $rc
}

os=$(uname -s 2>/dev/null || echo unknown)
if [ "$os" = Darwin ]; then
  codex_fix='brew install --cask codex'; magick_fix='brew install imagemagick'
else
  codex_fix='npm i -g @openai/codex'; magick_fix='sudo apt-get install imagemagick'
fi
venv_fix="python3 -m venv $VENV && $VENV/bin/pip install pillow"

# the Python that has Pillow: python3 on PATH first, then the venv doctor.sh --fix makes
find_python() {
  local c
  for c in "$(command -v python3 2>/dev/null)" "$VENV/bin/python"; do
    [ -n "$c" ] && [ -x "$c" ] || continue
    run_t "$PT" "$c" -c 'import PIL' && { printf '%s\n' "$c"; return 0; }
  done
  return 1
}

if [ "$want_python" = 1 ]; then find_python; exit $?; fi

fixes=()    # runnable fixes: commands the user may let --fix run
rc=0 notes=""
line() { printf '%-5s %s\n' "$1" "$2"; }

check_codex() {
  if ! command -v codex >/dev/null 2>&1; then
    line FAIL "codex: not on PATH | fix: $codex_fix, then run \`codex login\` yourself"
    case $codex_fix in "brew "*) fixes+=("$codex_fix") ;; esac
    rc=1; notes="$notes codex missing;"; return
  fi
  run_t "$T" codex login status; local s=$?
  if [ "$s" = 124 ]; then
    line slow "codex: codex did not answer in $T s"; rc=1; notes="$notes codex slow;"
  elif [ "$s" = 0 ]; then
    line ok "codex: logged in"
  else
    line FAIL "codex: not logged in | fix: run \`codex login\` yourself"; rc=1; notes="$notes codex not logged in;"
  fi
}

check_magick() {
  if command -v magick >/dev/null 2>&1 || command -v convert >/dev/null 2>&1; then
    line ok "imagemagick: found"
  else
    line warn "imagemagick: not found (recommended, for exact pixel moves and checks) | fix: $magick_fix"
    case $magick_fix in "brew "*) fixes+=("$magick_fix") ;; esac
  fi
}

check_pillow() {
  local py
  if py=$(find_python); then
    line ok "pillow: composite.py runs under $py"
  else
    line FAIL "pillow: no Python imports PIL, so box mode won't run | fix: $venv_fix"
    command -v python3 >/dev/null 2>&1 && fixes+=("$venv_fix")
    rc=1; notes="$notes pillow missing;"
  fi
}

[ "$quick" = 1 ] || check_codex
check_magick
check_pillow

if [ "$fix" = 1 ] && [ ${#fixes[@]} -gt 0 ]; then
  for cmd in "${fixes[@]}"; do
    if [ "$yes" = 0 ]; then
      if [ ! -t 0 ]; then echo "no terminal to ask at; not run: $cmd"; continue; fi
      printf 'run %s? [y/N] ' "$cmd"; read -r ans
      case $ans in y|Y|yes|YES) ;; *) echo "skipped"; continue ;; esac
    fi
    echo "running: $cmd"; bash -c "$cmd" || echo "that command failed: $cmd"
  done
  echo "checking again:"
  exec "$0" $([ "$quick" = 1 ] && echo --quick)
fi

if [ "$rc" = 0 ]; then echo "imagegen doctor: ok"; else echo "imagegen doctor: not ok:${notes%;}"; fi
exit "$rc"
