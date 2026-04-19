# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This repo ships `jailed-python` — a sandboxed wrapper around `/usr/bin/python3` — plus a Claude Code integration that pre-approves it and nudges Claude away from raw `python3`. Supported on **Linux** (via `bwrap`) and **macOS** (via `sandbox-exec`). The full test suite passes on both.

The project has been renamed twice (`pupbox` → `safe-python` → `jailed-python`). Migration code in the installer silently removes legacy binaries, allow rules, and CLAUDE.md marker blocks from both prior generations — don't delete that code without a replacement plan.

## Common commands

```bash
bash tests/run-all.sh              # run full test suite
bash tests/test_installer.sh       # run one test file
bash install.sh --help             # installer CLI
HOME=/tmp/h PREFIX=/tmp/p bash install.sh           # sandboxed install for manual checks
HOME=/tmp/h PREFIX=/tmp/p bash install.sh --uninstall
```

No build, no lint, no package manager — it's bash + a single installer script.

## Architecture

Three user-visible artifacts, plus an installer that stitches them into Claude Code:

1. **`bin/jailed-python`** — branches on `uname`:
   - **Linux:** `exec bwrap --ro-bind / / --unshare-all --tmpfs $HOME ... /usr/bin/python3`. Read-only FS, no network, ephemeral tmpfs for `$HOME`/`/tmp`/`/run`, dies with parent.
   - **macOS:** `exec sandbox-exec -p '<SBPL>' /usr/bin/python3`. Seatbelt profile: `(deny default)` + `(allow file-read*)` + `(deny network*)` + narrow `(allow file-write*)` for `/dev/null`, `/dev/std{out,err}`, `/dev/tty`, `/dev/fd/*`, `/dev/ttys*`. No tmpfs; writes outside those sinks fail outright. Requires Xcode CLT so `/usr/bin/python3` resolves.
2. **`hooks/python-nudge.sh`** — Claude Code `PreToolUse` hook. Reads the tool-call JSON on stdin, matches `python`/`python3` as a standalone command (anchored at start-of-string or after `|&;`` `$(`), and emits an `ask` permissionDecision plus an `additionalContext` block pointing to `jailed-python`. `permissionDecisionReason` is shown to the user; `additionalContext` is what Claude actually sees — without it the model never learns to switch. Silent on `jailed-python`, `jailed-python3`, `pytest`, `python3.11`, etc.
3. **`install.sh`** — single-file installer. Writes binaries to `$PREFIX/bin` (sudo iff not writable), hook to `$HOME/.claude/hooks/`, deep-merges `$HOME/.claude/settings.json` (adds allow rules + hook registration), and upserts an HTML-comment-delimited `## Python execution policy` block into `$HOME/.claude/CLAUDE.md`.

### Non-obvious invariants

- **`install.sh` embeds byte-identical copies of `bin/jailed-python` and `hooks/python-nudge.sh` as heredoc strings** (`JAILED_PYTHON_SCRIPT`, `PYTHON_NUDGE_SCRIPT`). This is what makes `curl | bash` work with no other files. `tests/test_installer.sh` fails if the embedded copies diverge from the source files — **edit both when changing either.**
- **Every installer step must be idempotent, reversible, and rename-safe.** `install_bins` removes legacy `safe-python`/`safe-python3` binaries before writing the current-generation ones. `merge_settings` prunes stale `Bash(safe-python:*)` allow rules before merging, and otherwise dedupes by structural equality. `upsert_claude_md` strips `jailed-python:policy`, `safe-python:policy`, and `pupbox:python-policy` marker blocks before re-writing. `--uninstall` removes all three generations of binaries, allow rules, and marker blocks. Tests enforce every one of these.

### Installer library mode

`install.sh` checks `JAILED_PYTHON_LIB_ONLY=1` at the bottom and skips `main` when set. Tests source it this way to call individual functions (`install_bins`, `merge_settings`, `check_deps`, …) with overridden `HOME`/`PREFIX`. Preserve this entry point.

## Testing conventions

- `tests/lib.sh` provides `test_case`, `assert_eq`, `assert_contains`, `assert_not_contains`, `assert_exit`, `summary`, `make_tmp`. Tests `cd` to repo root and `source tests/lib.sh`.
- Each test file ends with `summary` which exits non-zero on any failure.
- `run-all.sh` iterates `tests/test_*.sh` and reports aggregate pass/fail.
- `test_wrapper.sh` exercises the real sandbox — needs `bwrap` on Linux or `sandbox-exec` on macOS. The other test files run anywhere with `bash` + `jq` + `python3`.
- Migration tests (seeded legacy state → run installer/uninstaller → assert clean) live in `test_installer.sh`; keep one per legacy generation. They use the old marker strings / allow-rule names intentionally — don't "clean them up" into the current names.

## Settings.json merge semantics

`merge_settings` in `install.sh` is the reference: first prune stale `Bash(safe-python:*)` rules, then deep-merge where objects recurse, arrays concatenate then dedupe by structural equality, scalars let the patch win. When changing permission strings or hook shape, update the embedded patch, the uninstall filter (which removes by exact match across all generations), and the prune list.
