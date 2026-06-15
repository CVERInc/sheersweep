# Changelog

All notable changes to sheersweep are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/), and this
project adheres to [Semantic Versioning](https://semver.org/).

## [Unreleased]

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
