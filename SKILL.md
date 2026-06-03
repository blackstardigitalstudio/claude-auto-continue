---
name: claude-auto-continue
description: >-
  Resume Claude Code sessions automatically when usage/credit limits are hit.
  Use when the user wants work to "keep going", "continue automatically", "not
  stop at the usage limit", "resume after the quota resets", or to run a long
  task unattended. Wraps the `claude` CLI with `claude-ac` and registers a Stop
  hook that detects credit exhaustion and relaunches `claude --continue`.
---

# claude-ac — Auto-Continue for Claude Code

**Made in Italy** | v1.3.0 | MIT

## What this skill does

`claude-ac` wraps Claude Code so a long session is never lost to usage limits.
When a session stops because the quota/credit limit was reached, it waits for the
reset and automatically resumes the **same** session with `claude --continue` —
no manual intervention, no re-pasting context.

It works two ways, which complement each other:

1. **Wrapper** (`bin/claude-ac`) — run `claude-ac "<prompt>"` instead of
   `claude "<prompt>"`. It runs Claude, watches the output, and on a detected
   limit it waits and retries (`--continue`) up to `--ac-retries` times.
2. **Stop hook** (`hooks/stop.sh`) — registered in `~/.claude/settings.json`.
   It fires when a session stops, inspects the transcript, and if the stop was
   caused by a credit limit it launches a background daemon that resumes at reset.

## When to use it

- Long, unattended builds/refactors that may outlast the current quota window.
- The user says: "fai continuare il lavoro", "non fermarti al limite",
  "riprendi da solo quando si resettano i crediti", "keep working / auto-continue".

## How to install

```bash
git clone https://github.com/blackstardigitalstudio/claude-auto-continue.git
cd claude-auto-continue
./install.sh            # user-local (~/.local/bin); --system for /usr/local
```

The installer checks dependencies, copies the files, and (with `python3`)
**automatically merges** the Stop hook into `~/.claude/settings.json` after backing
it up. Without `python3` it prints the JSON snippet to add manually.

## How to use it

```bash
claude-ac "build me a todo app"          # start a task with auto-continue
claude-ac --continue                     # resume the last session
claude-ac --ac-interval 600 --ac-retries 6 "long task"
claude-ac --ac-help                      # all options
```

Key flags / env vars: `--ac-interval <sec>` (`CLAUDE_AC_INTERVAL`),
`--ac-retries <n>` (`CLAUDE_AC_MAX_RETRIES`), `--ac-verbose`, `--ac-no-notify`
(`CLAUDE_AC_NOTIFY=0`), `CLAUDE_BIN` to point at a non-default `claude` binary.

## Requirements & platforms

- `claude` (Claude Code) in `PATH`, plus `bash`, `grep`, `sed`. `python3`
  recommended for automatic `settings.json` merge.
- macOS / Linux / WSL. On **Windows** run it inside **WSL** or **Git Bash**
  (it is a pure-Bash tool, not a native `.exe`).

## Notes for the agent

- Detection is conservative: it only triggers on a non-zero exit and only scans
  the last ~60 lines of output for real limit markers (e.g. "usage limit",
  "rate_limit_error", "overloaded", HTTP 429), to avoid false positives from
  web/tool content read mid-session.
- The Stop hook respects `stop_hook_active` and uses a PID lockfile, so it never
  spawns overlapping resume daemons or loops on itself.

Made in Italy.
