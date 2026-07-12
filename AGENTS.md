# AGENTS.md — driving sheersweep as an agent

You are likely an AI coding agent (Claude Code, Codex, Antigravity, …) being asked
to use sheersweep. This file is your front door: read it and you can wield
sheersweep correctly on the first try — without deleting something the human wanted.
(Human-facing intro is in [README.md](README.md); the full command surface is
`sheersweep --help`, which is the SSOT — trust it over guessing.)

## What sheersweep is, in one breath

sheersweep is **the Mac cleaner you can read** — a single bash script (see
`wc -l sheersweep` for the current line count; more than half is its
nine-language strings) with **no telemetry, no daemon, no
network calls, no subscription**. The default **sweep** clears *only* regenerable
junk (caches/logs/temp the OS rebuilds) across **every** account under `/Users`,
then releases local APFS snapshots so the space actually comes back. It has a
**hard-coded never-touch list** no line in the script can reach.

**macOS only.** On a non-macOS host the disk-touching modes refuse to run and exit
non-zero; only `--version` / `--help` work everywhere.

## Driving it headless (the part you'll actually use)

```bash
sheersweep --dry-run                 # preview the sweep — deletes NOTHING (always do this first)
sheersweep                           # real sweep (re-execs with sudo: one password prompt)
sheersweep uninstall <App> --dry-run # preview one app's full footprint across all accounts
sheersweep uninstall <App>           # remove it → MOVES to Trash (never rm), typed-name confirm
sheersweep uninstall <formula>       # a Homebrew formula → DELEGATED to `brew uninstall`,
                                     #   dependency-checked, exact command shown, typed confirm
sheersweep uninstall <binary>        # a hand-installed bare binary → Trash, typed confirm
sheersweep tools                     # read-only CLI inventory (formulae/orphans/binaries/
                                     #   toolchain data) — changes nothing, no sudo needed
sheersweep leftovers --dry-run       # preview orphaned LaunchAgents/Daemons
sheersweep leftovers                 # remove dead/orphan startup items → Trash, yes/no confirm
sheersweep restore                   # undo the last uninstall/leftovers — put it all back
sheersweep restore --list            # show past removals
sheersweep --version                 # prints the current version; never needs sudo
```

Locale is auto-detected; force it with `SHEERSWEEP_LANG=en-US|ja-JP|zh-TW|zh-Hans|ko-KR|es-ES|de-DE|fr-FR|pt-BR`.

## Non-negotiable rules (a cleaner is destructive-adjacent — break one and you hurt the human)

1. **Dry-run first, every time.** Run `--dry-run`, read what it would free, *then*
   decide. The preview deletes nothing.
2. **Never bypass the human's confirmation gate.** `uninstall` waits for the human
   to **type the app's name**; `leftovers` / `restore` wait for an interactive
   yes/no. These prompts read from a TTY and are for the *human*, not you — do not
   pipe answers in, fake a TTY, or auto-confirm to "save a step." User excitement
   is not authorization.
3. **The sweep only clears regenerable junk** (`Library/Caches`, `Library/Logs`,
   `~/.cache`, `~/.npm`, Xcode DerivedData/DeviceSupport, CoreSimulator/Cargo/Gradle
   caches, already-uninstalled Adobe leftovers; system-wide `/Library/Caches`,
   `/.adobeTemp`, `brew cleanup`). It will never grow an "aggressive"/"deep" mode.
   Don't ask it to delete app data — that's what `uninstall` is for, on purpose.
4. **Honor the 🔴 never-touch list — and never route around it.** No line can reach:
   Photos / Documents / Desktop / Movies / Music, Clip Studio (CELSYS), app
   Containers & Application Support (except already-uninstalled Adobe), Dropbox /
   cloud-sync folders, screen recordings, Mail / Messages / Keychains, any git repo,
   any Obsidian vault. If the human wants one of these gone, that's a manual human
   action, not a sheersweep job.
5. **`uninstall` matches by bundle id, plus exact display-name paths that macOS
   itself uses — never a fuzzy/substring match**, and only ever *moves*
   to the owning account's Trash (no `rm`). It refuses sealed-system (`/System/*`)
   and the firmlinked Safari. Emptying the Trash is the human's final, deliberate
   step to reclaim space — that's the recoverability, don't shortcut it.
   For CLI tools the anchor changes but the rule doesn't: a Homebrew formula is
   matched by brew's own receipt and removed by **delegating to `brew uninstall`**
   (dependency-checked, exact command shown first; restore = `brew install`); a
   bare binary is matched by exact filename in `~/bin` / `~/.local/bin` /
   `/usr/local/bin` and moved to the Trash. sheersweep itself still never `rm`s —
   never "help" by trashing a Homebrew keg or its symlinks by hand; that
   half-uninstalls someone else's install and leaves brew's links dangling.
6. **Transparency over a black-box clean.** When you report what happened, report
   what the tool actually printed (the per-item sizes, the grand total, what was
   kept vs removed) — never assert a clean that didn't run or space that wasn't freed.

## Where to look

- `sheersweep --help` — the command surface, SSOT. Self-documents every mode.
- [README.md](README.md) — why-trust-it, scope-on-purpose, the full never-touch rationale.
- [CHANGELOG.md](CHANGELOG.md) — what changed and why.
- The `sheersweep` script itself — it's readable end to end; it deletes *your*
  files only via the sweep's `find … -delete` on the listed cache paths, or by
  *moving* to the Trash (`uninstall`/`leftovers`). The one `rm` it makes is
  discarding an empty receipt it just wrote itself — never your data. Anything
  else destructive is a tool's own uninstaller (`brew uninstall`, `brew cleanup`),
  delegated and shown verbatim before it runs.
