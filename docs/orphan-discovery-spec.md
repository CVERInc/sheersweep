# Orphan-data discovery — folding "residue of removed software" into `uninstall`

Status: **locked concept, not yet built** (maintainer decisions 2026-07-12).
Target: v0.7.0.

## The original vision this serves

sheersweep's sweep was always meant to reliably clear **the residue of software
you already removed** — not just Adobe. Adobe was the one case that got
hard-coded into the sweep, which is exactly why it broke the sweep's principle
(the sweep must clear *only* provably-regenerable junk; Application Support data
is neither provably regenerable nor safe to clear while the app is live).

## Two locked decisions

1. **Adobe leaves the sweep.** A vendor special-case in the "only regenerable
   junk" sweep violates the principle. Remove it.
2. **The general capability folds into `uninstall`, not a new/`leftovers` verb** —
   framed as *discovery*: the person finds out an app they removed long ago was
   never cleaned up. This completes a pattern `uninstall` already started (the
   `un_appgone` flow: "the app bundle is already gone — cleaning up just the data
   it left behind"). Today that only fires for a **named** catalog app; the
   generalization is for `uninstall` to **surface** provable orphans without being
   named.

## Why this is safe (the identity anchor, not a guess)

General "is this folder's app gone?" detection is the black-box-cleaner trap
sheersweep exists to avoid — *unless* it's anchored to identity. Split the residue:

- **Provable orphans (safe).** A large share of app data is named by **bundle id**:
  `Containers/<bid>`, `HTTPStorages/<bid>*`, `Saved Application State/<bid>.savedState`,
  `Group Containers/*<bid>*`, `Preferences/<bid>.plist` (+ `<bid>.*.plist`),
  `Application Scripts/<bid>`, `WebKit/<bid>`, `Cookies/<bid>.binarycookies`. For
  these you can **prove** orphanhood: enumerate every installed `.app`'s bundle id
  (across `/Applications`, `~/Applications`, system), and any id that owns data but
  is claimed by **no installed app** is a provable orphan. Same "match by id, never
  a name" rule as `uninstall` itself.
- **Name-named data (can't prove → never auto).** `Application Support/Adobe`,
  `/Spotify`, `/Code` are named by vendor/product, not bundle id — you can't map
  them to "is it installed?" without fuzzy matching. These stay a **curated
  catalog** (the vendor catalog `uninstall` already has) and may be surfaced only
  as a **⚠️ review** entry, never auto-cleaned.

Mirror `leftovers`' honest three tiers, at the data layer:
- 🧟 **provable orphan** (id-named, no installed app claims it) → safe to Trash
- ⚠️ **likely** (name-named, matches the curated vendor catalog) → opt-in only
- ✅ **keep** (id claimed by an installed app, or an unrecognized name) → untouched

## Shape

- `uninstall` with **no argument** shows the picker. Today it lists installed
  `.app`s. Add a second section:
  `Already removed — leftover data found (N):` listing provable orphans by bundle
  id with size. Selecting one runs the **existing** footprint→preview→typed-confirm
  →Trash→receipt→`restore` flow, keyed by the bundle id (id-named paths only — we
  have no trustworthy display name for a gone app, and inventing one would be the
  fuzzy match we forbid).
- This reuses `do_uninstall`'s machinery almost entirely; the new code is the
  **discovery enumeration** (collect data-bearing bundle ids, subtract installed
  ones) and the picker's second section.

## Adobe's exit, concretely

- Remove `clean "$home/Library/Application Support/Adobe"` and the
  `adobe_installed`/`adobe_gone` guard added in v0.6.0 (the guard was the right
  *patch*; removal is the right *architecture*).
- Remove `clean "$home/Library/Caches/Adobe"` too — it is **redundant**: the sweep
  already clears all of `Library/Caches` wholesale, so `Caches/Adobe` is a subset
  that was always going regardless. (Adobe's cache is genuine regenerable junk and
  stays cleared *via the parent sweep* — correct.)
- Net: the sweep no longer names any vendor. `Application Support/Adobe` moves to
  `uninstall`'s domain (catalog when named; ⚠️ curated discovery entry).
- **Docs simplify:** the never-touch list's "app Containers & Application Support
  (except already-uninstalled Adobe leftovers)" loses the exception — Application
  Support is now simply never touched by the sweep. Update README, AGENTS.md,
  SECURITY.md, and the 9-locale `--help` heredocs to drop the Adobe carve-out.

## Scope boundary (what this is NOT)

The **cache/log layer is already handled** — the sweep clears all of
`Library/Caches` / `Library/Logs` wholesale, regardless of which (gone or present)
app owns a subfolder. So orphan caches already disappear. This feature targets
exactly the **non-cache data layer** the sweep correctly never touches:
Application Support, Containers, Preferences, Saved State, Group Containers, etc.

## Open taste call (maintainer)

How to label a **nameless** provable orphan in the picker:
- **(default, honest)** bundle id + size, e.g. `com.spotify.client  —  340 MB`,
  optionally a dimmed hint derived from the id's last component (`spotify?`)
  clearly marked as a guess.
- vs. best-effort friendly name (risks implying a certainty we don't have).

Leaning toward id-with-a-dimmed-hint: it's the identity we can prove, and the
hint aids recognition without claiming a match.

## Hard edges the enumeration MUST handle (cold re-read, 2026-07-12)

Two failure modes found by re-deriving the design against the v0.6.0 code. Both
live in the *finder*, and both must be solved before the picker section ships:

1. **Helper-bundle false orphans — the dangerous one.** "Enumerate every
   installed `.app`'s bundle id" is under-specified. If it means top-level
   `/Applications/*.app` ids only, every nested helper bundle with its own id —
   XPC services, login items, Electron/Chromium helpers (`com.microsoft.teams2.launcher`
   inside Teams, `com.google.Chrome.helper.*` inside Chrome) — owns a live
   `Containers/<id>` that no top-level id claims. A naive subtract marks a
   **running app's helper container** as a provable orphan. A `.`-prefix rule
   doesn't close it either (vendors use divergent ids: `com.adobe.acc.installer`
   shares no prefix with any installed Adobe app id). The honest anchor:
   **an id is claimed if it appears as `CFBundleIdentifier` in ANY `Info.plist`
   inside any installed bundle** (`find /Applications ~/Applications ... -name
   Info.plist` within `.app`s — a few seconds, run once). And `com.apple.*` is
   ✅ keep unconditionally — system components own ids with no `.app` at all.

2. **Noise floor.** An old Mac carries dozens of orphan `Preferences/<id>.plist`
   at a few KB each (every past utility leaves one). Listing 60 four-KB ids
   drowns the discovery that matters — evidence becomes spam. Surface an orphan
   in the picker only if it has a **strong-family** presence (Containers /
   `Application Support/<bid>` / Group Containers / Saved State) **or** its
   aggregate size clears a floor (~1 MB); fold the tiny lone-plist tail into one
   dimmed count line (`…and N small preference files — shown with --all`).

(Also noted: `Group Containers` entries are team-id/group-named — attribution in
the discovery direction needs the same care as the wildcard match in
`do_uninstall`, not a new looser rule.)

## Inherited safety (unchanged)

Same as every destructive verb: preview the full footprint with sizes → type to
confirm → move to Trash (never rm) → receipt under `~/.sheersweep/uninstalls/` →
`restore` puts it all back. Provable-orphan detection adds a *finder*, not a new
deletion primitive.
