# sheersweep

[![CI](https://github.com/CVERInc/sheersweep/actions/workflows/ci.yml/badge.svg)](https://github.com/CVERInc/sheersweep/actions/workflows/ci.yml)

> The Mac cleaner you can **read**. Open source · dry-run first · a hard never-touch list · sweeps every account.
>
> **Scan · Confirm · Trash — the delete is yours.**

Most Mac cleaners are a black box that asks you to *trust* them while they delete
things you can't see, behind a subscription.
`sheersweep` is the opposite: it's **one short shell script you can read end to
end**, it **shows you exactly what it will free before it frees anything**, it
**only clears caches/temp/logs the OS rebuilds on its own**, and it has a
**hard-coded list of things it will never touch**.

Open source, no subscription, no surprises.

*The full teardown — how black-box cleaners work, and the APFS-snapshot trick most skip — is on the [devlog](https://cver.net/devlog/anatomy-of-a-scary-cleaner).*

## Why trust it

- **You can read every line.** It's one `bash` script (see `wc -l sheersweep` for
  the current line count) — more than half is its nine-language strings; the logic
  fits on a few screens. sheersweep itself never deletes a file except two easy-to-find
  ways: the sweep's `find … -delete` runs solely on the cache paths listed below, and
  `uninstall` *moves* files to the Trash — it never calls `rm`. Every other
  destructive action is a tool's **own** uninstaller (`brew uninstall`, delegated),
  and sheersweep prints the exact command before running it.
- **Dry-run first.** `sheersweep --dry-run` prints how much each item *would*
  free and deletes nothing. Run it, read it, then decide.
- **🔴 Never-touch list — no line in the script can reach these:**
  Photos / Documents / Desktop / Movies / Music, Clip Studio (CELSYS), app
  Containers & Application Support, Dropbox / cloud-sync folders, screen
  recordings, Mail / Messages / Keychains, any git repo, any Obsidian vault.
- **Only regenerable junk.** Everything it clears is a cache, a log, or temp that
  the OS and your apps recreate on next use.
- **The safety model is written down.** [`SECURITY.md`](SECURITY.md) lays out the
  full threat model in plain terms — the deletion surface, how the never-touch
  list is unreachable by construction, and the multi-account hardening — and how
  to report anything that overclaims.

## What it does

- For **every account** under `/Users` (current *and* future):
  `Library/Caches`, `Library/Logs`, `~/.cache`, `~/.npm`, Xcode
  `DerivedData` / `DeviceSupport`, CoreSimulator caches, Cargo/Gradle caches,
  and Node's per-user compile cache.
- System-wide, once: `/Library/Caches`, `/.adobeTemp`, `brew cleanup`.
- **The sweep names no vendor.** It clears only regenerable cache/log/temp
  locations — never a vendor's application data. (Adobe's residue, once a
  hard-coded special case here, is now found honestly by `uninstall`'s
  discovery below.)
- **Releases local APFS (Time Machine) snapshots** — the step most cleaners skip
  and most users never hear about: deleting files won't return the space if a
  snapshot still pins it. sheersweep frees it *and* tells you.
- **Ends with a read-only digest** of what the *other* verbs can see right now —
  scanned in the background while the sweep works, numbers and pointers only:

  ```
  ── Also seen (numbers only — nothing was touched) ──
     🧟 24 removed apps left 1.6G of data behind   → sheersweep uninstall
     ♻️ 4.5G of rebuildable build output (20 folders)   → sheersweep reclaim
     ↑ 5 Homebrew formulae have updates   → sheersweep tools
     🤖 AI session archives hold 512M — history isn't regenerable; use your AI tool's own cleanup
  ```

  Each line names its verb; the digest never acts. (AI session archives are
  conversation history — not regenerable, so not sheersweep's to touch: it
  reports the size and points at the owning tool, full stop.)

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

- **Matched by bundle id, plus exact display-name paths that macOS itself
  uses — never a fuzzy/substring match.** It reads the app's identifier and
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

### It also *discovers* what removed apps left behind

Delete an app by dragging it to the Trash and its data stays — Containers,
Application Support, preferences — sometimes for years. Run the picker and
sheersweep shows you, unprompted:

```
🧟 Already removed — leftover data found (4):
  64) com.spotify.client                    340M  (spotify?)
  65) com.wacom.UpgradeHelper               128K  (upgradehelper?)
  …
```

This stays inside the same identity rule that governs everything else: a large
share of app data is named **by bundle id**, and an id is surfaced only when
**nothing installed claims it** — the claim scan reads every installed app's
bundle ids (including every helper/XPC nested inside, at any folder depth),
driver and updater bundles under `/Library`, and every Launch Agent/Daemon
whose program still exists. No name-guessing anywhere: the `(spotify?)` hint is
explicitly a guess derived from the id; the id is the identity. Everything is
listed — the small scraps too, numbered under a divider at the bottom, because
you can't select what you can't see. Pick one and it runs the same preview →
typed-confirm → Trash → receipt flow; pick **many** (`5 7-8 19`, or `all` for
every 🧟 row) and the selection may mix apps and leftovers freely — selection
is batch, consent is not. Each selected **app** still walks its own preview and
typed-name confirmation, one at a time (`all` never touches app rows); the 🧟
rows then run as one batch: one combined preview of every file, one
confirmation (you type the count of ids shown), one receipt — and
`sheersweep restore` undoes the whole batch. Years of residue, one pass.
`sheersweep uninstall <bundle-id>` reaches a single one directly (add
`--dry-run` to preview headlessly).

One more honesty rule: **the ✅ only appears if everything actually moved.**
macOS protects app containers from other programs (even as root) unless your
terminal has Full Disk Access — when that blocks an item, sheersweep marks it
`❌ still in place`, reports `🔴 only N of M moved`, and tells you about the
System Settings toggle instead of pretending.

### CLI tools use the same verb — removed the way each restores best

```bash
sheersweep uninstall ffmpeg              # a Homebrew formula → delegated to brew
sheersweep uninstall mytool              # a hand-installed binary → Trash, like an app
```

- **A Homebrew formula is removed by brew itself.** brew's receipt knows the keg,
  the links, the services; `brew install <name>` is a *cleaner* restore than any
  Trash copy (a keg is a rebuildable artifact, not user data — and hand-moving it
  would leave brew's links dangling). sheersweep refuses if anything installed
  depends on the formula, prints the **exact** `brew uninstall` command, and runs
  it only after you type the name. Config the tool kept in your home folder is
  reported as untouched — guessing it by name is exactly the fuzzy matching this
  script refuses to do.
- **A bare binary** (`~/bin`, `~/.local/bin`, `/usr/local/bin`) moves to the Trash
  with a receipt, and sheersweep says out loud that only its author knows whether
  it kept data elsewhere. Symlinks owned by Homebrew or an `.app` are never
  candidates — their owners uninstall them.

## See your CLI tools (read-only)

The list that never existed anywhere: `/Applications` you can scan with your eyes,
but the CLI side of a Mac has no shelf to look at — until now:

```bash
sheersweep tools
```

One read-only screen: the Homebrew formulae **you** chose (leaves, with sizes),
orphaned dependencies (`brew autoremove` candidates), hand-installed binaries no
manager owns, and the big toolchain data folders (`~/.rustup`, `~/.android`, …) —
each with the **native** command that removes it. It changes nothing, needs no
password, and never touches the network. Which to keep is your call — this verb
just finally lets you *see* what you have; sheersweep gives evidence, not verdicts.

Upgradable formulae are flagged inline (`apfel  1.5.0  ↑ 1.8.3  brew upgrade
apfel`) — read from **brew's local index**, so even this stays offline: it's
exactly as fresh as your last `brew update`, and the summary line says so.

## Clean up leftovers (opt-in)

Apps you removed long ago often leave a **background item** behind — a
`LaunchAgent` or `LaunchDaemon` that still tries to run at login. `leftovers`
finds them across every account:

```bash
sheersweep leftovers             # find orphaned startup items (preview + confirm)
sheersweep leftovers --dry-run   # preview only
```

The point isn't finding *more* — it's being **honest about what's actually junk**:

- **🧟 Dead** — the program it launches no longer exists (e.g. an EA Origin helper
  whose binary is gone). Safe to remove.
- **⚠️ Likely orphan** — it references an app that's now missing (e.g. a
  discontinued app's self-remover). Shown for review; removed only if you opt in.
- **✅ Kept** — anything whose program still exists is left alone and counted. A
  *working* updater that a still-installed app shares (say, the Google updater that
  Google Drive needs) is **never** mistaken for junk — the trap dumb cleaners spring
  to scare you into deleting something load-bearing.

Chosen items move to the Trash and are logged, so **`sheersweep restore`** undoes a
leftovers sweep too. The system list catches up after the next login/restart.

## Reclaim build output (opt-in)

Build output is the heaviest junk on a developer's Mac — `node_modules`, Swift
`.build`, Cargo `target`, `dist` — tens of GB across a dozen repos, all
rebuildable with one command. It is also exactly where black-box cleaners lose
people's data. So `reclaim` splits what it finds by how sure it can be. The
**proven** tier is a candidate **only when three proofs hold at once** — git
ignores it, its name is on a short allow-list, and a sibling manifest
(`package.json`, `Cargo.toml`, `Package.swift`…) proves the build tool; these
show a rebuild command and clear in one typed-count batch.

But the folder that actually balloons a disk is often the one it *can't* prove
— a big gitignored crawl or export, no manifest, an off-list name. Hiding that
is the one thing a cleaner you trust shouldn't do, so `reclaim` also surfaces an
**unidentified** tier: heavy (≥512 MB, override `SHEERSWEEP_SUSPECT_MIN_MB`),
gitignored, in a cold repo. It proves nothing and says so — labelled
`unidentified`, never "dangerous" (it can't prove either), **never auto-picked**,
removed one at a time only if you type its name (the same friction as
`uninstall`), with a peek at its contents so you can recognise it. What git was
never told to ignore is never offered. The never-touch list still applies on top
(an Obsidian vault is skipped outright).

```bash
sheersweep reclaim               # proven → typed-count batch, then unidentified → typed-name each
sheersweep reclaim --dry-run     # preview only (headless-friendly)
sheersweep reclaim --stale 30d   # only repos untouched for 30+ days
```

The preview is the anti-black-box payload made concrete — not "Junk: 3.8 GB —
Clean", but:

```
♻️  ~/Developer/snapsift
   1) app/.build           773M   rebuild: swift build    · 14d untouched
♻️  ~/Developer/motifmint
   2) node_modules         263M   rebuild: npm install    · 31d untouched
```

What it is, how to rebuild it, how stale it is — *you* judge alive vs dead;
the machine never decides a repo is "done". Staleness is honest: the newer of
the last commit and the newest **tracked-file** edit, so an actively-edited
repo can never look stale. Selected folders move to the **Trash** — a
same-volume rename, instant, no copying — under one receipt. `sheersweep
restore` puts them back, and because the receipt records each **rebuild
command**, it also shows the cleaner alternative: rebuild a fresh tree
instead. Two undos, one promise. Design notes:
[`docs/reclaim-spec.md`](docs/reclaim-spec.md).

## Install & use

```bash
git clone https://github.com/CVERInc/sheersweep.git
cd sheersweep

./sheersweep --dry-run        # preview — deletes nothing (recommended first run)
./sheersweep                  # real run (prompts once for sudo — needed to sweep all accounts)
./sheersweep uninstall        # pick an app — or removed apps' leftover data — to clear
./sheersweep tools            # read-only: your CLI tools, orphans, toolchain data
./sheersweep leftovers        # find orphaned startup items from apps that are gone
./sheersweep reclaim          # build output in your repos — 3 proofs, then Trash
./sheersweep restore          # undo the last uninstall/leftovers/reclaim — put it all back
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
`sudo` (one password prompt). `--version` / `--help` / `tools` never need it.

## Putting the verbs together

sheersweep has no "clean everything" button and no scenario-specific modes —
just a few verbs that each do one thing. The interesting tasks are combinations,
the way `ls | grep | wc` is. A few that come up, so the shape is easy to picture:

**Inheriting a Mac — clear the previous owner's apps, keep their account.**
Someone hands you a machine; you have admin but not the old login. Remove what
they installed without deleting the account itself (so their login picture and
home folder stay).

```bash
sudo sheersweep uninstall SomeApp        # names resolve across every account's ~/Applications
sudo sheersweep uninstall /Users/prev/Applications/SomeApp.app   # or point straight at it
sudo sheersweep leftovers                # orphaned startup items from apps now gone
```

The account's **shell** — its home folder, login picture, documents — is left
alone, because no verb reaches it. "Keep the account, clear its apps" isn't a
mode: it's simply what remains when you only remove what you name. To delete the
account *itself*, that's macOS's job — System Settings › Users & Groups. sheersweep
clears contents; it doesn't create or destroy accounts.

**Handing a Mac to the next person — wipe your traces, leave the OS pristine.**
Uninstall the apps you added, clear their startup leftovers, then sweep the
regenerable junk. Everything an app removal touches goes to the Trash, so you can
walk it back until you empty it.

```bash
sudo sheersweep uninstall AppA && sudo sheersweep uninstall AppB
sudo sheersweep leftovers
sudo sheersweep                          # the sweep: caches/logs/temp the OS rebuilds
```

**Reclaiming a dev machine's disk — build output first, then the rest.**
The heavy, regenerable stuff (`node_modules`, `target/`, `.next`…) is its own
verb because removing it is safe *only* when it's provably rebuildable.

```bash
sudo sheersweep reclaim --stale 30d      # build output in repos untouched for a month
sudo sheersweep                          # then the ordinary cache/log sweep
```

Each line above is a verb you can run on its own, preview with `--dry-run`, and
undo with `sheersweep restore` (for the ones that move to the Trash). Nothing
here is a special path through the code — it's the same handful of verbs, ordered
by you.

## Scope, on purpose

The default **sweep** clears **only** safe, regenerable junk. It will never grow
"aggressive" or "deep" modes that rummage through app data hoping to find more to
delete — that's exactly where cleaners delete something you wanted.

Removing an app *is* deleting real data, so it's **not** folded into the sweep.
It's a separate verb you invoke on purpose — one app at a time for anything
still installed (that's surgery), in one previewed, explicitly-confirmed batch
for the residue of apps already gone (that's housekeeping) — and everything it
moves goes to the **Trash**, so the call is reversible. A narrow, honest sweep
and an explicit, recoverable uninstall — never a single broad "clean
everything" button.

## Language

The interface speaks **nine languages** — Deutsch (de-DE), English (en-US),
Español (es-ES), Français (fr-FR), 日本語 (ja-JP), 한국어 (ko-KR), Português
do Brasil (pt-BR), 简体中文 (zh-Hans), and 繁體中文 (zh-TW) — auto-detected
from your system locale. Consent prompts and judgments are fully localized; command
lines, paths, and sizes stay raw, because that vocabulary *is* the interface you
copy, run, and search. Force a language with:

```bash
SHEERSWEEP_LANG=ja-JP ./sheersweep --dry-run
```

**Adding a language is a welcome, self-contained PR.** Everything lives inside
the one script, in three places: one `xx-XX) echo "…" ;;` line per string in
`t()`, one help heredoc in `print_help`, and one detection line in
`ss_resolve_lang`. Then run `scripts/test.sh` — it extracts every string key
*and* every locale from the script itself and points at exactly what's missing.
CI runs the same gate on every pull request (a macOS job), so a partial
translation can't merge silently — it fails visibly, with the missing keys
named. Baseline translations are machine-grade; native-speaker refinements are
gladly taken.

## Requirements

**macOS only.** sheersweep is built for macOS and nothing else — it relies on
`tmutil` (local APFS snapshots), the APFS data volume, the standard `/Users` home
layout, and each account's `~/.Trash`. It is pure `bash` + the system tools that
ship with macOS, so there is **nothing to install**.

Run on a non-macOS host, the disk-touching modes (sweep / uninstall / restore)
**refuse to run** with a clear message rather than misbehave against a different
filesystem layout; only `--version` and `--help` work everywhere. The snapshot
step also degrades cleanly if `tmutil` is somehow absent.

## License

Published by **CVER Inc.** · [cver.net](https://cver.net) · [more open-source tools](https://github.com/CVERInc) · MIT License.
