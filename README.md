# sheersweep

[![CI](https://github.com/CVERInc/sheersweep/actions/workflows/ci.yml/badge.svg)](https://github.com/CVERInc/sheersweep/actions/workflows/ci.yml)

> The Mac cleaner you can **read**. Open source · dry-run first · a hard never-touch list · sweeps every account.

Most Mac cleaners are a black box that asks you to *trust* them while they delete
things you can't see, behind a subscription, with a little fear in the marketing.
`sheersweep` is the opposite: it's **one short shell script you can read end to
end**, it **shows you exactly what it will free before it frees anything**, it
**only clears caches/temp/logs the OS rebuilds on its own**, and it has a
**hard-coded list of things it will never touch**.

The honest cleaner. No subscription, no scare tactics, no surprises.

## Why trust it

- **You can read every line.** It's one `bash` script — ~670 lines, more than half
  of which are its three-language strings; the logic fits on a few screens. Only two
  operations delete anything, and both are easy to find: the sweep's `find … -delete`
  runs solely on the cache paths listed below, and `uninstall` only ever *moves*
  files to the Trash — it never calls `rm`.
- **Dry-run first.** `sheersweep --dry-run` prints how much each item *would*
  free and deletes nothing. Run it, read it, then decide.
- **🔴 Never-touch list — no line in the script can reach these:**
  Photos / Documents / Desktop / Movies / Music, Clip Studio (CELSYS), app
  Containers & Application Support (except already-uninstalled Adobe leftovers),
  Dropbox / cloud-sync folders, screen recordings, Mail / Messages / Keychains,
  any git repo, any Obsidian vault.
- **Only regenerable junk.** Everything it clears is a cache, a log, or temp that
  the OS and your apps recreate on next use.

## What it does

- For **every account** under `/Users` (current *and* future):
  `Library/Caches`, `Library/Logs`, `~/.cache`, `~/.npm`, Xcode
  `DerivedData` / `DeviceSupport`, CoreSimulator caches, Cargo/Gradle caches,
  and leftover Adobe caches/support.
- System-wide, once: `/Library/Caches`, `/.adobeTemp`, `brew cleanup`.
- **Releases local APFS (Time Machine) snapshots** — the step most cleaners skip
  and most users never hear about: deleting files won't return the space if a
  snapshot still pins it. sheersweep frees it *and* tells you.

It sweeps **all accounts** in one pass — handy on a shared or family Mac where
every other tool only cleans the user running it.

## Uninstall an app (opt-in)

A second, deliberate verb — for when you actually want an app *gone*: the app
**and every trace it left behind, across every account**.

```bash
sheersweep uninstall                     # pick from a numbered list of your apps
sheersweep uninstall Discord             # …or name it directly
sheersweep uninstall Discord --dry-run   # preview only — moves nothing
```

It's held to the same trust rules as the sweep:

- **Matched by bundle id, never a fuzzy name.** It reads the app's identifier and
  finds *its* files — not everything that happens to share a word.
- **Preview first, typed confirmation.** It lists the whole footprint grouped by
  account, with sizes and a grand total, then waits for you to type the app's name.
- **Reversible — it moves to the Trash, never `rm`.** Every uninstall writes a
  small receipt, so **`sheersweep restore`** puts the *entire* last removal back —
  across every account — in one command. That's the real undo a `rm`-based
  uninstaller can't give you. Emptying the Trash is what finally reclaims the space.
- **Refuses only what truly can't go.** Apps on the sealed, read-only system volume
  (`/System/*`) and the firmlinked Safari are off limits — not even `root` can
  remove them, and deleting them wouldn't free space. But **removable Apple apps in
  `/Applications`** (iMovie, GarageBand, the iWork suite, Xcode…) are fair game.

## Install & use

```bash
git clone https://github.com/CVERInc/sheersweep.git
cd sheersweep

./sheersweep --dry-run        # preview — deletes nothing (recommended first run)
./sheersweep                  # real run (prompts once for sudo — needed to sweep all accounts)
./sheersweep uninstall        # pick an app to fully remove (preview + confirm + Trash)
./sheersweep restore          # undo the last uninstall — put it all back
./sheersweep --version
./sheersweep --help
```

Installed via Homebrew? Drop the `./` — `sheersweep`, `sudo sheersweep uninstall`, etc.

Prefer a double-click? Copy it to your Desktop and rename to `sheersweep.command`,
or symlink onto your `PATH`:

```bash
ln -s "$PWD/sheersweep" /usr/local/bin/sheersweep
```

Sweeping every account needs admin rights, so sheersweep re-runs itself with
`sudo` (one password prompt). `--version` / `--help` never need it.

## Scope, on purpose

The default **sweep** clears **only** safe, regenerable junk. It will never grow
"aggressive" or "deep" modes that rummage through app data hoping to find more to
delete — that's exactly where cleaners delete something you wanted.

Removing an app *is* deleting real data, so it's **not** folded into the sweep.
It's a separate verb you invoke on purpose, one app at a time, that previews
everything and moves it to the **Trash** so the call is reversible. A narrow,
honest sweep and an explicit, recoverable uninstall — never a broad, scary
"clean everything" button.

## Language

The interface speaks **English (en-US), 日本語 (ja-JP), and 繁體中文 (zh-TW)**,
auto-detected from your system locale (Traditional Chinese only — Simplified falls
back to English). Force one with:

```bash
SHEERSWEEP_LANG=ja-JP ./sheersweep --dry-run
```

## Requirements

macOS (uses `tmutil`, APFS, the standard `/Users` layout). Pure `bash` + system
tools — no dependencies to install.

## License

MIT © [CVER Inc.](https://cver.net) — *making delightful digital tools since 2011.*
