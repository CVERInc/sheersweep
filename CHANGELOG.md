# Changelog

All notable changes to sheersweep are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/), and this
project adheres to [Semantic Versioning](https://semver.org/).

## [0.6.0]

- New verb: **`sheersweep tools`** — a **read-only** inventory of the CLI side of
  the Mac, the list that never existed anywhere: the Homebrew formulae *you*
  chose (`brew leaves`, with sizes), orphaned dependencies (`brew autoremove`
  candidates), hand-installed binaries no manager owns (`~/bin`, `~/.local/bin`,
  `/usr/local/bin` — Homebrew-keg and `.app`-bundle symlinks are excluded, their
  owners uninstall them), and the big toolchain data folders (`~/.rustup`,
  `~/.android`, …) each with its **native** removal method. Changes nothing,
  never asks for a password, never touches the network
  (`HOMEBREW_NO_AUTO_UPDATE=1` on every brew call).
- **`uninstall` now covers CLI tools — by delegation, not surgery.** A Homebrew
  formula is removed by brew itself: sheersweep refuses if any installed formula
  depends on it, prints the **exact** `brew uninstall <name>` command it will
  run, and runs it only after the usual typed-name confirm (restore =
  `brew install <name>`; the removed version is shown). A keg is a rebuildable
  artifact, not user data — reinstalling is a *cleaner* restore than any Trash
  copy, and hand-moving a keg would leave brew's links dangling. Config a tool
  kept in the home folder is explicitly reported as untouched — matching by
  name would violate the no-fuzzy-match rule.
- **`uninstall` also takes a hand-installed bare binary** (`~/bin`,
  `~/.local/bin`, `/usr/local/bin`): moves **just the binary** to the Trash with
  a receipt (`restore` undoes it) and says out loud that any data it kept
  elsewhere is unknowable. Manager-owned symlinks are never candidates.
- **The trust sentence got *stronger*, not weaker**: sheersweep itself still
  never deletes a file except by moving it to the Trash — every other
  destructive action is a tool's *own* uninstaller, shown verbatim before it
  runs. (`brew cleanup` in the sweep already worked this way.)
- **i18n is now tiered**: consent/judgment sentences stay fully localized
  (en-US · ja-JP · zh-TW — a func-test enforces all three per key); command
  lines, paths, sizes and table rows print raw — that vocabulary *is* the
  interface you copy, run, and search.
- **Wider functional test coverage** (no behaviour change): `lf_scan`'s
  dead/likely-orphan/kept classification (a live or Apple item is never flagged),
  multi-account Trash routing (each account's item lands in its *own* Trash),
  `restore` undoing a `leftovers` sweep, the sweep's `clean()` delete semantics
  (real empties-but-keeps-the-dir; `--dry-run` deletes nothing), and locale
  resolution (Traditional Chinese maps through; Simplified + others fall back to
  English).

## [0.5.0]

- **`uninstall` now reaches vendor-nested app data** — the gap that let a real
  `sheersweep uninstall "Google Chrome"` move only the `.app` and a prefs plist
  while leaving **~1 GB of profile** behind. Some apps don't store their data at
  `Application Support/<AppName>` or `/<bundle id>`; they nest it under a vendor
  folder (`Application Support/Google/Chrome`, `…/BraveSoftware/Brave-Browser`,
  …). A small, readable **catalog keyed by bundle id** now adds those paths to the
  footprint. Covers Chrome (+ Canary), Edge, Brave, Vivaldi, Arc, and Chromium.
- **Shared-vendor guard (`extra_is_safe`)** — a runtime refusal that no catalog
  entry can route around: a *vendor root* (`Application Support/Google`) is never
  removable, because it also holds a **different, possibly still-installed app's**
  data (Google Drive's `DriveFS`, the shared updater). The catalog only ever lists
  *product* subfolders; the guard makes a future typo impossible to act on.
- **`uninstall` works on an already-removed app** — if the `.app` is gone but the
  target is a catalog app, `uninstall <name>` still resolves it (by name → bundle
  id, or a literal bundle id) and cleans up the data it left behind, instead of
  failing with "no app named …". Same preview → typed-name confirm → move-to-Trash
  (recoverable via `restore`) flow; nothing new is auto-deleted.

## [0.4.0]

- New verb: **`sheersweep leftovers`** — finds orphaned startup/background items
  (`LaunchAgents` / `LaunchDaemons`) left behind by apps that are **gone**, across
  every account. The honest part is the **classification**:
  - **🧟 Dead** — the program the item launches no longer exists (e.g. an EA Origin
    helper whose binary was removed). Auto-selected.
  - **⚠️ Likely orphan** — an interpreter-run item that references an `/Applications`
    app that's now missing (e.g. a discontinued app's self-remover). Shown for
    review; only removed if you type `all`.
  - **✅ Kept** — anything whose program still exists is left untouched and counted,
    so a *working* updater shared by a still-installed app is never mistaken for
    junk (the trap dumb cleaners fall into).
  Preview-first; moves chosen items to the Trash and writes a receipt, so
  **`sheersweep restore`** undoes a leftovers sweep too. Full effect after the next
  login/restart. `--dry-run` only previews. Apple's own (`com.apple.*`) jobs are
  never touched.

### Hardened the uninstall/restore edge cases (no behaviour change on the happy path)

- **Uninstall receipts are now NUL-framed**, so a path containing a TAB or a
  NEWLINE — both legal in a macOS filename — can no longer corrupt the receipt or
  the `restore` parse. The header stays human-readable; data rows are
  NUL-terminated `dest`/`orig` pairs read with bash's own `read -d ''`.
- **Trash name-collisions are now unique to the nanosecond + a probe counter.**
  Trashing several same-named items within one second used to clobber the earlier
  one (a coarse second-stamp); now every one is kept.
- **A recreated `~/.Trash` is given the home folder's owner and mode `0700`**, so
  it's a Trash the user can actually empty and that other users can't read into.
- **`restore` now surfaces failures** (a parent dir it can't create, a move that
  fails) on stderr and exits non-zero, instead of silently skipping the item.
  Cross-filesystem restores work via `mv`'s copy+remove fallback.
- **`restore` claims its receipt atomically before touching anything**, so two
  overlapping `restore` runs can't both work the same uninstall.
- **The picker and `resolve_app` now find symlinked `.app`s and tolerate app
  names with spaces, quotes, or newlines** (NUL-delimited `find -print0` /
  `sort -z`; match by name + `[ -d ]` instead of `-type d`).
- **`tmutil` failures are reported, not swallowed**, and the snapshot step
  degrades cleanly when `tmutil` is absent.
- **macOS-only is now explicit**: the disk-touching modes refuse to run on a
  non-Darwin host with a clear message (`--version` / `--help` still work
  anywhere); README states the requirement and the degradation.
- Added a macOS functional test suite (`scripts/func-test.sh`, run by
  `scripts/test.sh` on Darwin) that reproduces each of the above as a regression
  guard.

## [0.3.1]

- The uninstall picker now finds apps nested **one folder deep** (e.g.
  `CLIP STUDIO 1.5/CLIP STUDIO.app`, the Wacom suite) — it never descends into a
  `.app` bundle's embedded helpers. Previously only top-level `/Applications/*.app`
  showed up, so subfolder apps were invisible.
- The picker header now shows the **total count**, so it's clear the list is
  complete (no hidden "next page").

## [0.3.0]

- New verb: **`sheersweep restore`** — undo the last uninstall. Every uninstall now
  writes a small, readable **receipt** (`~/.sheersweep/uninstalls/`), and `restore`
  reads it to move each item from the Trash back to exactly where it came from —
  across every account, in one command. `sheersweep restore --list` shows past
  uninstalls. This is the thing a `rm`-based uninstaller structurally can't offer:
  a real undo.
- Uninstall now refuses apps **by where they live, not by who made them.** Removable
  Apple apps in `/Applications` (iMovie, GarageBand, the iWork suite, Xcode…) are
  now fair game; only apps on the sealed, read-only system volume (`/System/*`) and
  the firmlinked Safari are refused. The picker surfaces removable Apple apps too.
- The uninstall completion message now points at `sheersweep restore`.

## [0.2.0]

- New opt-in verb: **`sheersweep uninstall <App>`** — fully removes one app and
  everything it left behind, across **every account** under `/Users`.
- Run **`sheersweep uninstall`** with no name to get an **interactive picker**: a
  numbered list of your removable apps (Apple/system apps filtered out) — pick one.
- Matches the footprint by the app's **bundle identifier** (read from the `.app`),
  never by a fuzzy name — covering `Application Support`, `Caches`, `Preferences`,
  `Containers`, `Group Containers`, `Saved Application State`, `HTTPStorages`,
  `WebKit`, `Cookies`, `Application Scripts`, `Logs`, per-user `LaunchAgents`, and
  system `LaunchDaemons` / `PrivilegedHelperTools`.
- **Preview-first**: prints the whole footprint grouped by account, with sizes, a
  grand total, and the resolved bundle id, before doing anything.
- **Reversible by design**: on a typed-name confirmation it *moves* each item into
  the owning account's **Trash** (never `rm`), so deletions can be recovered;
  emptying the Trash is what reclaims the space. `--dry-run` only previews.
- **Refuses** Apple / system apps (`/System/*`, `com.apple.*`) and any app with no
  bundle id. Asks the app to quit first (best-effort).
- The default sweep is unchanged — its "never touches your real files" promise and
  never-touch list still hold; uninstall is a separate verb you opt into.

## [0.1.0]

- First slice: the honest, readable Mac cleaner.
- Sweeps **every account** under `/Users` (current and future): `Library/Caches`,
  `Library/Logs`, `~/.cache`, `~/.npm`, Xcode `DerivedData`/`DeviceSupport`,
  CoreSimulator caches, Cargo/Gradle caches, leftover Adobe caches/support.
- System-wide: `/Library/Caches`, `/.adobeTemp`, `brew cleanup` (run as the real
  user, never root).
- Releases local APFS (Time Machine) snapshots so freed space actually returns.
- `--dry-run` previews every item's size and deletes nothing.
- Hard never-touch list (photos, documents, app data, Clip Studio, cloud sync,
  repos, vaults). The only delete call runs solely on the listed cache paths.
- Re-execs with `sudo` to sweep all accounts; `--version` / `--help` need no sudo.
- Trilingual UI — **en-US / ja-JP / zh-TW**, auto-detected from the system locale
  (Traditional Chinese only; Simplified falls back to English). Override with
  `SHEERSWEEP_LANG=en-US|ja-JP|zh-TW`. Language is resolved before the sudo
  re-exec and passed through, so it survives privilege escalation.
