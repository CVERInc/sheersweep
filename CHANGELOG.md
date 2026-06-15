# Changelog

All notable changes to sheersweep are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/), and this
project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
