# Changelog

All notable changes to sheersweep are documented here.
The format follows [Keep a Changelog](https://keepachangelog.com/), and this
project adheres to [Semantic Versioning](https://semver.org/).

## [0.17.0]

### Fixed — a section header that promised a method and handed back a noun

`tools`' toolchain section is headed *"remove with each tool's own method"*, and
the README went further: *"each with the **native** command that removes it."*
Seven of its eleven rows had no command in them at all:

```
   ·   4.7 GB  ~/.android  (Android emulator/adb data)
   ·   340 MB  ~/.m2  (Maven cache)
```

`Android emulator/adb data` is a definition wearing the costume of an answer. On
the machine this was found on it was the **only** row that printed, and it was
4.7 GB — the reader follows the header, finds a noun, and leaves with nothing.

Every row now carries a method, in one of two shapes and never a third: a
command behind `→`, or — when the tool genuinely has none — a *localized note in
parentheses that says so*. "No single command" is an answer; a noun is not.

```
   ·   4.7 GB  ~/.android
     → avdmanager delete avd -n <name>
   ·   340 MB  ~/.m2
     (Maven's local repository — no prune command; it refills on the next build)
```

One row changed what it points at rather than what it says: `~/go` became
`~/go/pkg/mod`. `go clean -modcache` clears the module cache, and `~/go` is your
**workspace** — printing that command beside a 5 GB `~/go` claims a scope it
does not have. The other partial commands carry a `<placeholder>` that already
reads as per-item (`nvm uninstall <version>`), so they kept their folder.

### Changed — one screen, one arrow, one way of saying "none"

Four conventions were sharing one screen. Now:

- **`→` means a command you can paste into a shell.** Nothing else uses it. A
  symlink's destination — which is not a command — moved to `↳`, and
  `Android Studio → SDK Manager` (a GUI path wearing the command glyph) is gone.
- **Paths under your home render as `~/…`**, the rule the sweep's rows have
  followed all along, now lifted into a shared `tilde` and reused by the CLI
  previews. The binaries section printed `/Users/you/.local/bin/agent →
  /Users/you/.grok/bin/agent` under a header that said `~/.local/bin`, and the
  full home path twice in one row pushed the destination off the edge:

  ```
  ·   130 MB  ~/.local/bin/agent  ↳ ~/.grok/bin/agent
  ```

  `/usr/local/bin` stays absolute: it is not under anyone's home, and `~/` there
  would be a lie about where the file is.
- **The next step sits at the tail of the section it belongs to**, not three
  sections away at the foot of the screen. Orphaned dependencies had named
  `brew autoremove` in prose since it was written but never offered it as
  something runnable; it does now, when there is anything to run it on.
- **Empty sections answer.** The formulae section could print its `▸` header over
  blank space — the exact shape the orphans section was fixed out of, fixed there
  and nowhere else. The three *inventory* sections now share one `(none)`.
  Orphaned dependencies keeps `[ PASS ]`, deliberately: it is a **check**, and
  nothing stranded is a clean result. An empty shelf passes nothing.
- `(Homebrew not found — skipping formulae)` gets the blank line every other
  section got.

### Fixed — the one preview that printed a path raw

`uninstall <bare-binary>` printed its path without `vis()`. Every other consent
screen strips terminal control bytes before printing, for the reason the
function's own comment gives: these lines sit directly above the typed-name
prompt the whole tool's safety rests on, and a filename may carry ESC. It was
the last one printing unsanitized.

### Added — `tools` had no tests at all

- `tilde`: `~/` inside the home, absolute outside — and `/Users/chodaictx` is
  **not** inside `/Users/chodaict`. That is the same prefix trap 0.16.2 fixed for
  bundle ids, one release later in a different alphabet.
- Every toolchain row must carry a usable method, and every note must resolve in
  all nine locales. The first version of this gate rejected an empty hint and a
  stray `→` — and a bare `Maven cache` walked straight between them, which is
  precisely the defect above. It now requires the hint to *be* a command.
- The rendered screen: `~/` paths, `↳` for symlink targets, and no `▸` header
  left standing over empty space.

All four were confirmed by breaking the script on purpose and watching each one
fail. A gate nobody has seen fail is a gate you only know is quiet.

## [0.16.2]

### Fixed — one app's uninstall reached another app's data

`uninstall CLIP STUDIO` listed three files belonging to **CLIP STUDIO PAINT** — a
different application, still installed — and would have moved them to the Trash:

```
▸ CLIP STUDIO   ·   jp.co.celsys.CLIPSTUDIO
   ·   369 KB  /Users/chodaict/Library/HTTPStorages/jp.co.celsys.CLIPSTUDIOPAINT
   ·     4 KB  /Users/chodaict/Library/HTTPStorages/jp.co.celsys.CLIPSTUDIOPAINT.binarycookies
   ·   4.0 MB  /Users/tin/Library/HTTPStorages/jp.co.celsys.CLIPSTUDIOPAINT
```

`jp.co.celsys.CLIPSTUDIO` is a **prefix** of `jp.co.celsys.CLIPSTUDIOPAINT`, and
three families are reached by glob because their real names carry affixes:
`HTTPStorages/<id>*`, `LaunchAgents/<id>*.plist`, `Group Containers/*<id>*`
(a team id sits in front there). A bare `<id>*` is a prefix match, and prefixes
cross app boundaries. README and AGENTS.md both promise *"matched by bundle id …
never a fuzzy/substring match"* — this is what makes that sentence true.

A dot is the only boundary a bundle id has, so a glob hit now has to **be** the
id or **sit between dots**: `<id>`, `<id>.anything`, `anything.<id>`,
`anything.<id>.anything`. `…CLIPSTUDIO` + `PAINT` is none of those.
`EQHXZ8M8AV.group.com.google.drivefs` still is, and verifying that mattered as
much as the fix — the failure mode of a boundary rule is quietly dropping the
rows it was meant to keep. Both directions were checked against the same machine:
the three PAINT rows are gone, every Google Drive row survives.

Applied to all eight glob sites, including the two in orphan discovery — where
the same prefix could make a removed app's id "claim" a live app's data, and
`orphan_has_data` decide an id was worth surfacing on the strength of it.

**How it was found:** the maintainer ran `uninstall --dry-run`, picked three
rows, and read the preview. Nothing was deleted, no test caught it, and the tool
printed the evidence itself — which is the argument for a preview that lists
every path by name rather than a count and a total.

## [0.16.1]

### Fixed — two receipts in the same second, and `restore` offered the earlier one

`restore` finds the last uninstall by filename order, and every receipt is named
`<stamp>-<slug>.tsv`. Two written inside the same second therefore ordered by
their **slug** — so an app removed at `23:12:42` followed by leftover rows
confirmed at `23:12:42` could leave `restore` pointing at the app, calling it the
last thing you did. Alphabetically `com.…` beats `orphans`; nothing about that is
a fact regarding which happened first.

It is the same defect [0.15.4] fixed from the other end: an undo pointer aimed at
somebody's earlier, deliberate removal. Receipts now carry a two-digit sequence
between the stamp and the slug, counted against every receipt already stamped
that second, so filename order *is* creation order. Old receipts keep their names
and stay readable — the sequence only has to be right going forward.

Reachable in one picker run, which is exactly what 0.16.0 made routine: apps,
leftovers and startup items now each take one short typed count, and three
confirmations can land inside one second.

### Fixed — `restore --list` said "newest first" and printed oldest first

The header has promised newest-first for as long as the list has existed. The
loop walked the ascending glob, and walked `*.tsv` fully before `*.tsv.restored`,
so restored rows were also grouped at the end regardless of when they happened.
On this machine that put today's removals at the bottom of forty-one rows, under
a heading pointing at June.

One reverse byte-order sort over both patterns now, NUL-framed because a slug
carries a bundle id and an app's display name.

*Both are the kind of bug a test finds and a person doesn't: the list has been
wrong for months in plain sight, and the receipt collision needs two confirmed
removals inside one second — so both new tests shim `date` rather than race it.*

## [0.16.0]

### Changed — picking six apps now costs one preview and one confirmation

Multi-select was batch selection with serial consent: six rows meant six full
previews, each ending in the app's name typed out by hand. The friction of one
deliberate removal is right; the same friction six times is not more safety, it
is the thing that teaches a person to type through a prompt without reading it.
Six `[ DONE ]` lines scroll past and nobody re-reads number four.

So app rows now take the shape the leftover (🧟) rows and startup items already
had: **one combined preview of every file, grouped by app — name and bundle id
both — one grand total, and the COUNT of apps typed once.** All or nothing; a
wrong count cancels the batch and touches nothing. The picker *is* the selection
step — you chose by row, off a list already on screen — so re-proving each app's
identity afterwards was asking a question that had been answered.

Nothing else moved: same footprint per app, same Trash (never `rm`), same
`[ HELD ]` accounting when macOS holds a container back. The batch writes **one**
receipt instead of six, so `sheersweep restore` puts the whole pass back in one
step — it used to take six restores, run in reverse order, to undo one decision.

**One picked app is still typed by name.** It isn't a batch, and typing `1` is
not a fact you had to read anything to know. `all` still refuses to mean "every
installed app" — it only ever takes the discovered rows.

### Fixed — two copies of one app consented to the same folder twice

`~/Applications/Foo.app` and `/Applications/Foo.app` share a bundle id, so they
share `Application Support/Foo`. Serially that was invisible (the second run
found the folder already gone and listed it at 0 KB). In one list it would have
been printed twice, consented to twice — and *moved* twice, where the second
move finds nothing and `trash_one` honestly counts a miss: a clean run reported
as "only 3 of 4 items could be moved". The batch collapses to one row per path,
first occurrence wins.

### Fixed — it announced that every app "looks like it's running"

The quit-first line was printed before every removal, running or not: six picked
apps, six claims, most of them false — including `Claude Code URL Handler`, a
4 KB shim, and three Google Drive shortcut stubs. The claim is one `ps` away
from being checkable, so now it is checked: the line appears (and the Apple
Event goes out) only when a process is actually alive inside that bundle — a
helper or an `.appex` counts, since they hold the same files open. An
already-removed app has no bundle to run from and is never claimed to be running.

The check reads its process table into a variable *before* matching. A
`ps … | grep` pipeline starts both sides at once, so `ps` captures grep's own
command line — which contains the pattern being searched for — and every app on
the machine comes back "running". That version was written first, and it passed.

## [0.15.7]

### Fixed — the Chinese copy sprayed `——` where `：` belongs

Taiwanese house style asks for the em dash to be *rare*: most of the time the
clause after it either explains the one before (`：`) or is simply coordinate
(`，`). sheersweep had it in **41 of its zh-TW strings and 41 of its zh-Hans**,
which is not a stylistic tic at that density — it is one English punctuation
habit wearing a Chinese font.

The replacement is a judgement per line, so it was applied from a written-out
line-number table rather than a blanket substitution, and every target was
asserted present before the edit and absent after. A `replace()` that quietly
matches nothing and one that works look identical from the outside.

Untouched: the one Japanese string that uses `——`. That rule is zh-TW's, and
inventing a Japanese one to make the diff symmetrical would be a worse error
than the one being fixed.

### Fixed — the harness reported `✅` while the tool reported `[ PASS ]`

`func-test.sh` carries a comment explaining that exactly this makes a person
learn two vocabularies for one result. It then shipped `✅ ALL GREEN` in
`test.sh`, and `🧟` / `⚠️` inside two test names. The tool itself was clean;
only the scripts that grade it were not.

The CLI signet lint passed all three files, because its six checks cover
badges, the seal, bullets and rules — and **nothing covers emoji**. It was not
letting these through; it was never looking. Recorded rather than papered over.

## [0.15.6]

### Changed — `SECURITY.md` now records what a real machine proved, both halves

The container protection turned out to be stronger than the document said.
`rmdir` on an empty directory you just created in `~/Library/Containers` is
refused as well, and macOS *adopts* it — `containermanagerd` drops a metadata
plist inside, so the folder you made is a container you can no longer delete.
**Creating is permitted; moving and removing are not.**

And the other half, which had never been checked: granting the terminal Full
Disk Access and re-running **does** complete the move, receipt and all. The
`[ HELD ]` line is not a shrug — it is the actual next step, and now the document
says so because someone followed it.

*(Both established during a real multi-account run: 8 items across two accounts,
`[ DONE ] Moved 8 items from 5 removed apps`, verified against the receipt.)*

## [0.15.5]

### Changed — the container claim is now something you can re-run

`SECURITY.md` asserted that macOS blocks moving `Library/Containers/*` without
Full Disk Access. True, but an assertion — and a security document that asks to
be trusted on its own word is the thing this project exists to argue against.

It now carries the three-line probe that establishes it, touching nothing of
yours:

```sh
mkdir ~/Library/Containers/probe          # succeeds: creating there is allowed
mv ~/Library/Containers/probe /tmp/       # mv: … Operation not permitted
rmdir ~/Library/Containers/probe
```

A directory you just made, owned by you, with no flags and no ACL, still cannot
be *renamed* out of that folder. That EPERM is the whole story — it is the same
call sheersweep makes to move something to the Trash.

### Fixed — the docs still described the old glyphs

`SECURITY.md` promised a `🔴 only N of M` shortfall and a `✅ summary`; the tool
has printed badges since 0.11.0. `AGENTS.md` still pointed at a "🔴 never-touch
list". Both now say what the tool says — including the zero case added in
0.15.4, which `SECURITY.md` had no way to describe.

## [0.15.4]

### Fixed — an undo pointer that would have undone the wrong thing

With every item stuck behind Full Disk Access, a real run printed:

```
[ FAIL ] only 0 of 7 items could be moved to the Trash — the rest are still
         in place. Undo the moved ones: sheersweep restore
```

Nothing had moved, so there was nothing to undo — and the receipt for a run that
moved nothing is discarded by design. Following that pointer would have restored
the **previous** receipt: a deliberate uninstall from a minute earlier.

A pointer is a promise. Zero moved now gets its own sentence, with no undo
offered and the `[ HELD ]` explanation still there, because the reason is still
worth knowing:

```
[ FAIL ] None of the 7 items could be moved to the Trash — everything is still
         in place.
[ HELD ] What stayed behind are app CONTAINERS … Full Disk Access …
```

The suite had a case for a *partial* shortfall and none for a total one — the
gap that let a wrong pointer ship. It has all three now.

### Fixed — `▸ system-wide` over a path inside your own home

```
▸ system-wide
   ·     4 KB  /Users/chodaict/Applications/Claude Code URL Handler.app
```

The `.app` was filed under the system scope unconditionally. It now sits under
whichever account's Applications folder it lives in. Where it goes is unchanged
— the running user's Trash, Finder-like; that is the owner, not the label.

## [0.15.3]

### Fixed — one file was listed in two sections, and consented to twice

A real run picked `16-24` and got:

```
▸ Startup items to remove (2) — to the Trash; restore puts them back
   Found nothing belonging to startup.
```

Both plists had already gone to the Trash in the orphan batch a few lines
earlier. An orphan's footprint includes `LaunchAgents/<id>*.plist`, and
`com.dropbox.DropboxUpdater.wake.plist` belongs to the surfaced orphan
`com.dropbox.DropboxUpdater` — so the same file was a row in two sections. It
was picked twice, moved by the first pass, and the second pass then reported
finding nothing over an empty selection.

Nothing was lost — the second pass is a no-op by construction — but the count
was inflated, the consent was asked twice for one file, and "N of 19 startup
items" counted things another row already owned.

Startup rows now skip any plist an orphan id claims. **One file, one row, one
consent.**

*Found by running it for real. The sandbox suite could not have: it does not
have a machine with a Dropbox that used to be installed.*

## [0.15.2]

### Fixed — the picker died on `set -u` right after printing the whole menu

```
▸ Already removed — leftover data found (7)
    22)     4 KB  com.operasoftware.Opera
sheersweep: line 3027: LF_KEPT: unbound variable
```

`startup_discover` runs inside the picker's **background subshell**. Its rows
cross back to the parent through a temp file — but `LF_KEPT`, the count of live
startup items the header needs for its "N of TOTAL", was a variable, and a
variable does not survive a subshell. Anyone with at least one dead startup item
hit this; 0.15.0 and 0.15.1 are affected.

The count travels as a row now, the way the rows already did.

### Added — `scripts/picker-smoke.sh`, because the suite structurally cannot

The check that missed this called `startup_discover` **directly, in the same
shell** — a path that never runs in production. The functional suite couldn't
have caught it either: it is hermetic by design, and the picker scans
`/Applications` and every `/Users/*` home.

So the boundary gets its own check, run before a release, that exercises the
real path and asserts what the failure looked like: a non-zero exit, the words
"unbound variable", and any `{placeholder}` still sitting unfilled in the output
— that last one being the exact shape of a fact that failed to cross.

Verified the only way that means anything: with the fix reverted, it fails.

## [0.15.1]

*A pass against the project's own definition-of-done, looking for what was left
rather than declaring there was nothing.*

### Fixed — a claim on the README's first trust bullet was false

> "more than half is its nine-language strings"

Measured: the string table is **28%** of the file; on the most generous reading
(locale branches plus their `case`/`esac` scaffolding) it is 25%. The logic is
about half — 2400 lines, which is not "a few screens" either.

Both sentences were true once and drifted as the tool grew. The bullet now says
what the file measures, and says plainly that reading it is not a weekend job:
the promise is that **every line is there to be read**, not that it is short.

### Fixed — three fixed-width columns that a real name would still have sheared

The picker was fixed in 0.14.0; `tools` was not. Its formula column was padded
to 24 and its version column to 12 — while `brew leaves` on this very machine
reports `cverinc/sheersweep/sheersweep` (29) and a version string of 64
characters. Latent, not live, which is the only reason it hadn't been seen.

All three now put the variable-width field last, and the upgrade line takes the
settled two-line shape instead of riding inside the row:

```
   ·    85 MB  rclone 1.74.3
     → brew upgrade rclone   (1.74.4)
```

### Fixed — my own drift, made the same morning

Widening nine detail rows from `%6s` to `%8s` kept the old three-space gap, so
an unnumbered size row sat two columns to the right of the disk map's. Same row
type, two indents, introduced and shipped within a day.

### Added — tests for a destructive path that had never run

`do_uninstall_startup` was written in 0.13.0 and had **no test at all**. Found by
asking which knives had never been swung rather than which tests were green.
Three cases now: a wrong count moves nothing and writes no receipt, a right one
moves the plist to the Trash with a readable receipt, and `restore` puts it back.

### Changed — the closing hint in `tools` points like everything else

`Remove a formula … with: sheersweep uninstall <name>` became a context line and
a runnable pointer beneath it — the shape the spec already settled for a row
with a next step.

## [0.15.0]

### Changed — the app list is size-sorted too, so the rule has no exception left

Yesterday's rule was "the **sort key** leads", written to justify one list
holding two shapes: a name-sorted app section leading with the name, a
size-sorted orphan section leading with the size.

Asked whether the rule and the interface were really the same thing, the honest
answer was no — the name-sorted section was the exception and the rule had been
bent around it. Sorting everything by size removes the exception, the clause,
and a shape:

```
▸ Apps you can uninstall (13)
     1)   1.4 GB  ChatGPT
     2)   686 MB  Google Drive
     3)   562 MB  Obsidian
     …
    13)     4 KB  Claude Code URL Handler
```

It is also just better. **A picker is the discovery path, not the lookup path**
— anyone who knows which app they want already types
`sheersweep uninstall Discord`. What is left for the list is *what is on this
machine and what does each thing cost*, and that question wants the heaviest row
at the top. Which is the same reason the footprint is measured at all.

Ties break by name, so two same-sized apps don't shuffle between runs.

## [0.14.0]

### Removed — the guessed vendor hint

Every orphan row carried a parenthesised guess derived from its own id:

```
com.dropbox.DropboxMacUpdate    5.3 MB  (dropboxmacupdate?)
```

Measured against **1073 real bundle ids** on a working machine: **1067 of the
hints were the id's own last component, lowercased** — printed two columns from
the id itself. Of the six that stepped back to a vendor, two were worse than the
tail (`com.apple.quicklook.ui.helper` → `(ui?)`). Four in a thousand earned it.

It cost more than the noise. The startup section uses the same parentheses for a
*fact* and the same `?` for a guess; a mark that is filler 99% of the time
teaches the reader to stop looking inside the parentheses at all.

### Fixed — a long bundle id no longer shears the columns

`com.getdropbox.dropbox.alternatenotificationservice` is 51 characters and the
id column was 44, so the size column slid right and the list came apart.

Padding it wider would only move the number at which it breaks. The fix is the
rule the disk map has followed all along: **the sort key leads and the
variable-width field goes last**, so nothing is lined up against it and no input
can break the layout. These rows are size-sorted, so the size leads:

```
    19)    61 KB  com.getdropbox.dropbox.garcon
    20)    33 KB  com.getdropbox.dropbox.alternatenotificationservice
```

The app rows keep name-first because they are name-sorted — which is the same
rule, and means the first column of any section tells you how it is ordered.

## [0.13.2]

### Fixed — `restore --list` rendered an unreadable receipt as an empty one

Two receipts on the author's own disk predate the NUL-sentinel format. The
header parser splits on the first NUL, so for those files every field came back
empty and the row printed as blanks beside `0 item(s)` — indistinguishable from
an uninstall that moved nothing.

It says what it is now, and the bare `restore` path refuses one instead of
walking the whole flow to restore nothing and calling it a success.

**Deliberately not fixed by guessing.** The old layout was TAB-separated, and it
was replaced *because* a path may contain a TAB — a mis-parse here puts a file
back in the wrong place. Naming the file and stopping is the honest end of that
trade.

Found by reading real output rather than a fixture: the two rows were sitting at
the top of the list, sorted first because their date field was empty.

### Fixed — the restore list had no row mark

`   20260616-101300   ·   leftovers   ·   2 item(s)` → `   ·   20260616-…`.
A row you can read but not select takes `·`, like every other one.

## [0.13.1]

### Changed — seven consent prompts making three promises

`uninstall`, its brew and bare-binary branches, the orphan batch, `reclaim`, its
unidentified tier and the new startup section each had their own confirm string,
nine locales deep. They said three things: type a **name** and it goes to the
Trash, type a **name** and a command runs, type a **count** and a batch goes.

Sixty-three strings become twenty-seven. The friction *is* the consent — a
prompt that re-explains what the header above it just said is how a wall of text
trains a rubber stamp.

Two of them also got more truthful than they were. A wrong name in a batch skips
*that* item and the rest still come, which "anything else cancels" said wasn't
so; count-consent really is all-or-nothing, so it keeps "cancels".

### Removed — decorative glyphs from narration, and two keys nobody printed

`🧪` on the dry-run notes, `🔍` on the scanning notices, `ℹ️` on the info lines —
seventy-two of them across ten keys, while the sweep's own narration had already
dropped them and read fine. An info line isn't a state, so it takes no mark.

`dry_banner` and `dg_heavy_scanning` were translated nine ways each and printed
nowhere. Found by asking which keys the file references outside its own table.

### Changed — the receipt format is written down once

The receipt **is** the undo, and its header was spelled out in five places, four
of them character-for-character. That is four chances for a future verb to drift
a field `restore` then can't read. `receipt_open` / `receipt_close` hold it now;
callers say only what is theirs, and reclaim passes its rebuild commands as the
one thing about its receipt that isn't every other receipt.

Net **−96 lines** and six fewer keys, with no verb losing anything it did.

## [0.13.0]

### Removed — the `leftovers` verb. The picker asks its question now.

**Breaking:** `sheersweep leftovers` (and its `orphans` / `cruft` aliases) is
gone. Startup items whose program no longer exists are a section of
`sheersweep uninstall`.

The same question — *what did an app leave behind?* — had two front doors and
two vocabularies. The receipts had always gone to the same store, so `restore`
already undid either one; only the entrance was split.

What it is not: a transplant. The old verb's section had its own glyph (`↳`),
its own confirm, its own summary line. Rendered in the picker's language it
needs none of them — the missing program becomes a parenthesised hint, exactly
like an orphan's vendor guess, which is how the tool stopped needing a third
kind of arrow:

```
▸ [ WARN ] Still starting up — the program they launch is gone (1 of 19 startup items)
    65) com.dropbox.DropboxUpdater.wake                   —  (missing DropboxUpdater)
```

Two things that shape looks nothing like a size-sorted row for a reason. These
weigh **24 KB for the lot** on the author's machine and run at every boot, so
ranking them among apps by size would bury the only thing that matters about
them — hence their own section, and `—` where a size would go.

And `1 of 19` is the whole claim: eighteen were looked at and left alone. That
counter existed before only as a line the old verb printed; it is now what the
header says, and it is the same control the test suite uses to tell "skipped
every live item" from "never looked at anything".

An item that only *references* a missing app keeps its `?`, the picker's
existing mark for a guess, and is yours to judge.

### Changed — a row records what it is, instead of being worked out twice

Selecting a row used to be index arithmetic with the tier boundaries hard-coded
at both the render and the selection. Fine for two tiers; the reason a third was
awkward. Rows now record their own kind as they print, which retired
`orphan_row_id` entirely.

`all` reaches the new rows too, and the multi-select hint says so in all nine
languages rather than promising less than it does.

### Changed — every verb's headers, on one rule

- A **report title** carries no `▸` (`tools` wore one; sweep and reclaim don't).
- A **group header** carries `▸`, no trailing colon, and never opens with a
  badge — but *may* carry one after the mark: `▸ [ WARN ] Likely orphans …`.
  Two marks, two jobs: `▸` says a group starts here, the badge says what state
  it's in. That is the rule that state belongs to the group rather than to every
  row, which is why those sections had a badge in the first place.
- A **note** is not an item: `tools`' "N upgradable" line no longer wears a
  bullet in the size column of the list it follows.

## [0.12.0]

### Added — the picker shows what each app actually costs you

`sheersweep uninstall` with no name used to list bare app names. A bare name
can't answer the question people are actually asking there: "Discord" is a
keep-or-remove coin flip; **`Discord · 2.1 GB`** is a decision — at that size a
browser tab starts looking like the better deal. The number has to be on screen
while the choice is being made, not after it.

Each row is the app's **full footprint** — the bundle plus everything it owns
across every account — measured by the same walk `uninstall` uses for its
preview, now lifted into one `gather_footprint` so the picker and the preview
can never disagree about what an app is made of.

Sorted **by name**: you look an app up by what it's called. (The array is
sorted, not just the display — row N is `apps[N-1]` for the rest of that
function, so a display-only sort would have uninstalled the wrong app.)

Measured on the author's machine: **14 apps, ~1.0 s** for the whole list, behind
the same heartbeat the sweep uses. On a multi-account machine it walks every
home, so expect more.

### Fixed — a size column too narrow for the sizes in it

Nine detail rows across `uninstall`, `tools` and the brew inventory were six
columns wide, which is one short of `116.0 GB` and two short of the alignment
everything else on screen uses. They are eight now, and carry the family's `·`
like every other row you can read but not select.

### Fixed — the snapshot row was a count wearing a size column

```
·        1  (present)      →      ·        —  (1 · present)
```

A snapshot's size is the one number on this report that genuinely cannot be
measured: the space it pins is scattered across already-deleted files and
`tmutil` won't total it. The em dash says so, in the same voice as "unreadable
even to root". Written out rather than passed through `%8s` — bash pads by
BYTES, so an em dash (three bytes, one column) lands two columns short of every
MB beside it.

### Fixed — the i18n gate could not see a missing translation

It asked whether `t <key>` returned something in every locale. A key missing a
locale falls through to `*)` and returns English, which is very much something,
so the check could only ever catch a typo'd key name — while its comment claimed
it caught silent fallbacks. Found by writing the same weak check for sheerstatus
and watching it bless a four-locale section as nine.

The new one reads the shape: a key whose body opens `case "$SS_LANG"` is
claiming per-language text, so every locale must appear as a branch label. Hence
`en-US|*)` across all 116 branches — one label meaning both "English" and "any
language we haven't heard of" is what made a gap invisible. sheersweep itself
was clean; it was the gate that wasn't.

## [0.11.1]

### Fixed — `reclaim > file` was writing the narration into the file

`sheersweep reclaim --dry-run > report.txt` came out with a scanning cursor and
a progress notice sitting on top of the report; `reclaim`'s stderr was empty and
everything went to stdout. The sweep had already been split — **stdout is data,
stderr is narration** — and this verb had never been.

The banner stays on stdout, because it defines what the rows below mean, the
way `The sheersweep:` heads the sweep. It also lost its `▸`: it is the report's
title, and the `▸` headers under it are its groups, so it was competing with
them for the same mark.

### Fixed — a sweep that freed nothing measurable claimed it freed nothing

`0.0 GB freed` after clearing 57 MB is not a rounding artefact; it is the tool
saying it did nothing. The unit now follows the amount, so a small win reads as
a small win. And when free space doesn't go up at all — something else wrote
while the sweep ran — the sentence changes instead of the number:

```
[ DONE ] Swept · no space came back · 93% full
```

Reporting `-1.2 GB freed` would blame the tool for the machine.

### Fixed — `reclaim`'s numbered rows didn't line up

`1)` and `10)` sheared the size column apart, and the sizes themselves were
unpadded. Both are padded now, and the `↺` rebuild command starts at the column
the size starts in — the same relationship `→` has to its own row.

### Changed — one bullet, one group header

`•` is retired in favour of `·`, which was already doing both jobs everywhere
else: marking an item, and separating fields inside one. Thirty-six of them were
hiding in the localised `--help` text, which is why an earlier pass called this
tool consistent. **A tool's language includes the part you only read once.**

The uninstall picker gained the group header it never had, blank lines between
its three sections, and the family's indent.

### Changed — the badge set grew a sixth: `[ CRIT ]`

`PASS · DONE · WARN · CRIT · FAIL · HELD`. The five were derived from this tool,
which *acts*; a tool that *measures* runs a three-rung ladder, and flattening
"getting full" into "already thrashing" makes a report useless at the exact
moment it matters. Nothing in sheersweep emits `CRIT` today — the set is shared,
and it is now correct for the whole family.

## [0.11.0]

### Changed — status is five badges now, the same in every language

`✅ 🔴 ⚠️ ❌ 🔒 ✨` become **`[ PASS ] [ DONE ] [ WARN ] [ FAIL ] [ HELD ]`** —
eight columns wide, and never translated. This is the CVER CLI seal
(`signet/packages/cli`), shared with sheerstatus and clikae, so one language
carries across every tool in the family.

Not translating turns fixed width from a discipline into a property, makes
`grep WARN` work on a log pasted by someone in any language, and deletes dozens
of strings that could rot. The prose after a badge is still localised, so mixed
script is expected: `[ WARN ] メモリ：…`. The badge is the anchor; the sentence
carries the meaning. The padding is what keeps a badge from reading as a
checkbox.

Two glyphs turned out to be doing several jobs, visible only once each line had
to pick one badge:

- `✅` split by *did this change the disk?* — "No leftovers" and "Kept 23
  untouched" are `[ PASS ]`; "Moved 3 to Trash" is `[ DONE ]`. That makes
  `[ DONE ]` a claim that can be caught lying: a dry-run printing it is a phantom.
- `🔴` was carrying three — a protective refusal (a sealed system app, a formula
  others depend on → `[ HELD ]`), a partial move failure (`[ FAIL ]`), and "this
  tool is macOS-only", which is just a run that didn't succeed (`[ FAIL ]`).

And the per-row `[preview]` / `freeing` markers are gone. Whether a run deletes
or previews belongs to the *run* — it's in the banner and in the closing line,
and stamping it on twenty rows only teaches the eye to skip it. Rows are now a
plain `· size path`.

### Fixed — an empty account no longer prints anything at all

`clean()` meant to skip anything measuring 0B, but `du -sh | cut -f1` left-pads
its output, so the value was `"  0B"` and never matched the `"0B"` it was tested
against: the guard had never once fired. On a Mac with a second, idle account,
half the sweep's output was those dead lines. With them gone, a group heading
would have been left standing over empty space — so a heading now waits until
its group actually has a row.

### Changed — one report at the end of a sweep, not two

The digest ("Also seen", by category) and the 📦 disk map (by location) were
separate blocks built at different times, and on a full disk they collided —
the disk-fullness line was just a headline for what the map detailed right below,
and the same `→ tools` / `→ uninstall` pointers showed in both.

Now it's **one report**. The map always runs (the per-account `du` is a cost a
bare sweep already pays; a heartbeat covers the wait). The by-category findings
fold in as a **"Cleanable, inside the above"** group — build output, AI archives,
removed-app leftovers, brew updates — in the map's two-line language, biggest
first. It's a distinct group on purpose: those categories live *inside* the
account totals the map partitions, so summing them in would double-count and
break the "beyond reach" remainder. The standalone disk-% line is gone (the map
is that story).

### Changed — every verb now speaks one visual language

The output was a patchwork: `====`/`----` rules, and emoji whose spatial meaning
fought their intent. It's now one grammar, shared by the digest, the disk map,
and every verb — reached by a long back-and-forth over what each mark actually
earns its place doing:

- **No horizontal rules.** A `▸` group header and a blank line segment the output;
  a rule only implies a boundary without enclosing anything. 33 of them, gone.
- **Two-line entries** where an item has a next step: `· size (what)` then, indented
  beneath, `→ where to go`. The action column can't be thrown off by a CJK name in
  the label, because the label sits ragged-right.
- **Each symbol does one job.** `·` an item · `→` the next step *or* a version
  transition (`1.8.3 → 1.8.4`) · `▸` a group · `↺` how to rebuild · and state,
  which by the end of this release became the five badges described at the top.
- **Retired the decorations that carried no information a header didn't:** `🧰 🔺
  ♻️ 🧟 🤖 📊` as signage, and the line-start `↑` that read as "the line above."
- **One warning per group, not per row** — five stacked ⚠️ stop being read.
- The AI-session-archives digest line now points at `clikae clean` (its URL shown
  only when clikae isn't installed) — the honest next step for history sheersweep
  won't touch, the same way it points other accounts at System Settings.

### Added — the sweep now tells you when it's a drop in the bucket

The sweep only ever clears regenerable junk, which is a feature — but on a
nearly-full disk that honesty has a blind spot: you clean, reclaim a few dozen
megabytes, and you're still at 92%, with no idea why. The numbers were there
(`Free before` / `Free after`) but never the context.

This began as one extra digest line when the disk was tight, and ended up as the
whole-disk map below — which always runs and tells the same story in more detail,
so the standalone fullness line was folded into it before release.

Below it, when the disk is tight, a whole-disk **map** shows where the space
actually went, in three groups by what you can do about it:

- **System — leave it** — OS-owned roots (`/Library`, `/private/var`).
- **Here to stay** — your own live login (you can't delete the account you're in,
  and your real data isn't sheersweep's to take) plus, by subtraction, the SIP
  regions (version DB, Spotlight) *unreadable even to root* — no tool can total them.
- **Yours to act on** — another account (→ System Settings), the Homebrew prefix
  (→ `sheersweep tools`, taken from where brew actually is, so it's right on both
  Apple Silicon and Intel and blank when brew isn't installed), apps (→ `uninstall`).
  This group comes **last**, nearest the prompt, where you'll act from.

It only ever *shows* — it adds visibility, never a new thing to delete — and every
next-step pointer is a fact sheersweep can assert, never a guess (an unrecognised
path simply gets none). A per-account size on macOS means walking every inode (no
quotas), so on a full disk — exactly when this runs — it's slow. Rather than
promise a duration we can't honestly keep (a fuller disk is slower), it prints a
notice and a heartbeat while it measures. Read-only, and silent on a disk with room.

### Fixed — `uninstall <name>` now sees every account, matching what it can remove

The footprint collector always swept `for home in /Users/*`, but the name
resolver only looked in the invoker's own `~/Applications` — so an app installed
only under *another* account (inheriting a Mac, a departed user) could be deleted
by explicit path but not found by name. The resolver now searches every account's
`~/Applications`, the invoker's first so a same-named app still resolves to yours.
What you can sweep, you can now see — the gap this tool exists to close.

### Changed — reclaim reads in the same visual language as the disk map

`reclaim`'s list now speaks the layout the whole-disk map introduced: size-first
(`· 714M (path)`, the number you scan for up front), a `▸` repo header per group,
and — the real point — each artifact's rebuild command as a **full, paste-anywhere
line** on its own row: `↺ cd /abs/path/to/parent && npm install`. reclaim's
artifacts don't go to the Trash (they're too big), so that command IS their
"reversible": it has to run from a fresh shell, so it's absolute, never assuming
you're in the repo. The proven gate already requires a manifest beside the
artifact, so the parent is guaranteed buildable — the command is correct by
construction, not a guess. The "unidentified" tier (can't prove it's safe) now
carries a ⚠️ and, deliberately, no `↺`: we won't hand you a rebuild line we can't
stand behind. The decorative 🔺 is retired in favour of that ⚠️.

### Docs — a "Putting the verbs together" section

Scenario recipes (inheriting a Mac, handing one on, reclaiming a dev disk) shown
as *combinations of the existing verbs*, not new modes — the Unix way. "Keep the
account, clear its apps" is documented as what remains when you only remove what
you name, not as a feature to build.

## [0.10.3]

### Changed — the unidentified confirm prompt is now terse

The per-item 🔺 prompt led with "Unidentified — I can't prove this is safe." every
time. But a wordy confirmation trains the exact reflex a safety gate exists to stop:
faced with a wall of text, a human just agrees. The honesty already lives — once — in
the section header; the real gate is having to type the folder's own name, which you
can't rubber-stamp. So the prompt is now just `Type '{name}' to move it ({size}) to
the Trash, anything else skips:` in all nine languages. Less to read, same gate.

## [0.10.2]

### Changed — reclaim now picks both tiers from ONE numbered list (uninstall model)

v0.10.0 numbered only the proven rows; the unidentified 🔺 rows had no number and
were force-marched one-by-one after the proven pick. That was confusing — you
naturally try to pick a 🔺 row by "its number", there wasn't one, and the per-item
prompts then marched in size order regardless of what you wanted (field-reported).

Now proven (1..n) and unidentified (n+1..) share **one numbered list and one pick
prompt** — exactly like `uninstall`. Selection is unified (pick any rows by number);
confirmation still scales with confidence: a proven pick clears in the one typed-count
batch, and each picked 🔺 row asks you to type its name (with a peek at its contents)
before it moves. `all` still means the proven batch only — the careful 🔺 rows stay
opt-in by number. Nothing is auto-selected; nothing skips the type-to-confirm gate.

## [0.10.1]

### Fixed — the reclaim banner still claimed "nothing else is even visible"

v0.10.0 added the unidentified tier and moved the promise in the help, README, and
AGENTS.md — but missed the two lines printed by `reclaim` itself: the top banner
(`rc_banner`) still said "manifest-proven; nothing else is even visible", and the
empty-state (`rc_none`) only mentioned proven output. Both now tell the truth in all
nine languages: `reclaim` also surfaces heavy gitignored folders it can't identify.
No behaviour change — the tier already worked; the words it prints now match it.

## [0.10.0]

### Added — `reclaim` now also surfaces the heavy folders it *can't* prove

`reclaim`'s three gates (gitignored + known name + sibling manifest) deliberately
hide anything they can't prove is regenerable. The cost of that conservatism was a
blind spot: the folder that actually balloons a disk — a big gitignored crawl, an
export, a model cache, with no manifest and an off-list name — stayed invisible and
was never offered. Hiding the fat unprovable folder is the one thing a cleaner you
trust shouldn't do; the person who knows what it is never got asked.

So `reclaim` now shows a second, clearly-separated **unidentified** tier: gitignored
+ heavy (≥512 MB, override with `SHEERSWEEP_SUSPECT_MIN_MB`) + in a cold repo, minus
whatever the proven scan already listed. It proves nothing and says so — the label is
`unidentified`, never "dangerous" (the tool can't prove either). These are **never
auto-selected and never batch-deleted**: each is confirmed one at a time by typing its
name (the same friction as `uninstall`), with a peek at its biggest contents so you
can recognise it. Everything still moves to the Trash, lands in the same receipt, and
is undone by `restore`.

### Changed — the `reclaim` promise, to match

The proven tier is unchanged: still three gates, still the typed-count batch, still a
recorded rebuild command. But `reclaim` no longer claims "a folder it can't prove
stays invisible" — it now surfaces those for you to judge. The behaviour and the words
moved together (help / AGENTS.md / README), because a cleaner that says one thing and
does another is the exact black box this tool exists not to be.

## [0.9.1]

### Changed — multi-select may now mix apps and 🧟 rows

- A picker selection like `19-20 5 7 8` — live apps and leftovers together —
  now just works. The parser used to refuse any multi pick containing an app
  row, and refused it with a message that named no reason (a field report
  caught it: someone followed the on-screen example and got "Not a valid
  choice"). The rule is now **batch selection, serial consent**: every
  selected app still walks its own preview → typed-name confirmation, one at
  a time (a wrong name skips that app, the rest still come); the 🧟 rows then
  run as one batch with the count-typed confirmation, one receipt.
- `all` is still 🧟-only, deliberately: a one-word input must never be able
  to mean "uninstall every installed app".
- The hint line teaches the whole grammar now and shows on every menu.

## [0.9.0]

### Added — the sweep digest: one habitual command surfaces everything

- Every sweep (real or `--dry-run`) now ends with a **report-only digest** of
  what the other verbs can see right now: data left behind by removed apps
  (→ `uninstall`), rebuildable build output (→ `reclaim`), upgradable
  formulae (→ `tools`, same offline read), and — from ~100 MB — the size of
  AI-session archives, pointed at the owning tool (conversation history is
  not regenerable and never sheersweep's to touch).
- **Numbers and pointers, zero new deletion surface.** Each line is produced
  by the same finder its verb uses; a finder that found nothing contributes
  no line, and an empty digest prints nothing at all.
- **No perceptible slowdown:** the finders run in the background *while* the
  sweep works; at digest time there is a short bounded grace (a few seconds,
  usually zero), then whatever is ready prints — a missing line, never a
  stall. No new flags: the digest is part of what a sweep is now.
- Why: a cleaner is reached for in moments, and the habitual moment is the
  plain sweep. The digest hangs the rare, high-value verbs on the frequent
  one — the tool argues for its own slot with evidence instead of marketing
  (design record: `docs/digest-spec.md`).

## [0.8.0]

The `reclaim` verb ships — the June 21 spec (`docs/reclaim-spec.md`), built as
designed.

### Added — `reclaim`: build output in your repos, three proofs or invisible

- **`sheersweep reclaim [--dry-run] [--stale <N>d] [path…]`** finds build
  output inside project folders (`node_modules`, `.build`, `target`, `dist`,
  `.next`, `Pods`, gradle dirs) — but a folder is a candidate **only when
  three proofs hold at once**: git ignores it, its name is on the short
  allow-list, and a sibling manifest (`package.json`, `Cargo.toml`,
  `Package.swift`/`.xcodeproj`, `Podfile`, gradle files) proves the build
  tool. A data folder merely named `dist` fails the manifest gate and stays
  invisible. Obsidian vaults and cloud-sync mirrors are skipped outright.
- **The preview is the argument:** grouped by repo, each row carrying size,
  the exact **rebuild command** (lockfile-aware — pnpm/yarn/bun/npm), and
  honest staleness (the newer of last commit and newest *tracked-file* edit,
  so an actively-edited-but-uncommitted repo can never look stale).
  `--stale 30d` turns that column into a filter.
- **Same primitive as every verb:** pick rows (`1 3 5-8` / `all`), type the
  count, and folders move to the **Trash** — a same-volume rename, instant,
  no copying — under one receipt with honest accounting. The receipt records
  each rebuild command (`kind=reclaim`), so **`restore` offers two undos**:
  put the files back, or rebuild a clean tree with the printed command.
- Scan roots are an explicit, readable list (`Developer`, `Projects`, `Code`,
  `src`, `repos`, `workspace` — whichever exist, in every account) or the
  paths you pass; never a walk of the whole home.

### Added — sweep: Node's per-user compile cache

- The sweep now clears `node-compile-cache` inside each account's confstr
  temp directory (resolved as that account) — one *named* cache dir; still
  not, and never, a wholesale `/var/folders` sweep. The spec's other Layer-1
  candidates were already covered wholesale (`Library/Caches/*`,
  `brew cleanup`) and were deliberately not duplicated.

## [0.7.5]

Housekeeping — no behavior change. The CI badge had been red since v0.6.0
(an older shellcheck on the runner flags `A && B || C`; split into two lines),
the functional suite now runs on a macOS runner for every PR — which makes
the "a partial translation can't merge silently" promise machine-enforced —
and the README lists the nine languages A-Z by locale code. Released so the
tagged tarball matches `main` byte for byte: this project asks you to read
the script you installed, so the script you installed should be exactly the
one on display.

## [0.7.4]

Found the honest way, live: three real batch runs printed ✅ while every single
`Library/Containers/` item silently stayed put — macOS protects app containers
from other programs, **even running as root**, and the `mv` failure vanished
into a `2>/dev/null`. Receipts don't lie (143 moves, zero containers among
them); summaries did. This release makes the summaries as honest as the receipts.

### Fixed — no more ✅ on a run that moved nothing

- Every move loop (uninstall, orphan batch, bare binary, leftovers) now counts
  **tried vs moved** through one shared, accounted path (`trash_one`). An item
  that couldn't be moved says so right there (`❌ still in place`), and the
  summary turns into `🔴 only {moved} of {total} items could be moved` the
  moment the numbers disagree — the plain ✅ only appears when everything
  actually moved. A run that moved nothing no longer claims success (it used
  to print ✅ *and* silently delete its own empty receipt).
- When the stuck items are app containers, sheersweep prints the one line that
  actually helps: **grant your terminal Full Disk Access** (System Settings →
  Privacy & Security), then rerun — verified end-to-end on a protected
  container (mv fails as root without it; succeeds with it). Another account's
  containers may additionally require logging in as that account. sheersweep
  never asks for this permission itself; it tells you when macOS wants it and
  leaves the decision where it belongs.

### Changed — zh-TW wording aligned with macOS

- 「卸載」→「移除」 across all zh-TW strings and help, matching Apple's own
  Taiwanese-Chinese system vocabulary.

## [0.7.3]

### Changed — the menu arrives in one piece

- 0.7.2 overlapped the orphan scan with reading the app list — but that meant
  the 🧟 section arrived seconds after the apps: a menu in halves reads as a
  stutter, and a late-growing list is exactly what a person starts typing
  against. The apps are now *collected* during the scan but *printed* with it:
  one announced wait up front (the 🔍 line says the menu arrives complete),
  then everything at once. Same scan, same overlap, calmer screen.

## [0.7.2]

### Changed — the orphan scan hides under your reading time

- The picker used to print the app list, *then* announce the scan, then pause
  for several seconds (maintainer field report: the notice "shouldn't show up
  late — it should come out with the apps"). The scan now starts **first, in
  the background**, with the 🔍 notice at the very top — by the time you've
  browsed the app list, the 🧟 section is usually already waiting. Same scan,
  same results; the wait just overlaps the seconds you were spending reading
  anyway. (Results cross the subshell boundary via a temp file of TAB rows —
  every field is id-shaped, so nothing needs escaping; if `mktemp` fails, the
  scan simply runs inline as before.)

## [0.7.1]

v0.7.0's discovery found the residue; v0.7.1 makes it *removable in one pass*.
(Field-tested immediately: a real Mac surfaced 42 orphans plus 56 small
leftovers — and one-at-a-time selection turned out to be 98 rounds of typing.)

### Added — pick many orphans at once

- The picker's 🧟 rows now take a **multi-selection**: `19 20 25-32`, commas
  ok, or `all`. A batch shows ONE combined preview — every file, grouped by
  id, with sizes and a grand total — then asks you to **type the count of ids
  shown** (a number you can only know by reading the summary; 42 typed app
  names don't scale, 42 unread `y`s don't inform). Everything moves to the
  Trash under **one receipt**, so `sheersweep restore` undoes the whole batch.
- Live apps deliberately stay one-at-a-time with the typed-name confirm:
  removing an installed app is precise surgery; removing residue is
  housekeeping. A multi-selection may therefore contain only 🧟 rows.

### Changed — the small leftovers are listed, not folded

- v0.7.0 folded sub-1 MB, weak-family orphans into a count line
  (`…plus 56 small leftover preference files`). That was a verdict, and this
  tool promises evidence: you can't select what you can't see. The tail is now
  **listed and numbered** under a divider — size-sorting already sinks it to
  the bottom, so the big finds still lead.

### Fixed — the group namespace could still nominate

- The `group.*` rule from v0.7.0 missed the namespace's other two spellings:
  `systemgroup.*` and the 10-character **team-id first label**
  (`EQHXZ8M8AV.group.com.google.drivefs`). Through Application Scripts
  sandboxes and stray Preferences plists, a **live Google Drive's** group
  container surfaced as a 6 MB "provable orphan" and a live Wacom driver's as
  another. All three spellings are now rejected at the id-shape level
  (`looks_like_bid`), so no source can nominate them — while a proven orphan's
  group data still rides along with its footprint.

## [0.7.0]

The original wish behind sheersweep was always "reliably clear the residue of
software I already removed" — this release makes that a real, provable feature
instead of one hard-coded vendor. Design notes: `docs/orphan-discovery-spec.md`.

### Added — `uninstall` discovers what removed apps left behind

- **The no-argument picker grows a second section:** `🧟 Already removed —
  leftover data found (N)`, listing data that apps you removed long ago never
  cleaned up — largest first, with sizes and a clearly-marked recognition guess
  (`com.spotify.client  340M  (spotify?)`). Picking one runs the *existing*
  footprint → preview → typed-confirm → Trash → receipt flow, so `restore`
  undoes it like any uninstall. `sheersweep uninstall <bundle-id>` reaches the
  same flow directly (works headless with `--dry-run`).
- **Provable orphans only — identity, never a guess.** A large share of app data
  is named by bundle id (`Containers/<id>`, `Preferences/<id>.plist`, …). An id
  is surfaced only when *nothing installed claims it*; the claim scan covers
  every Applications folder at full depth (vendors nest apps three levels down),
  every Info.plist nested *inside* each non-Apple bundle (XPC services, login
  items, Electron helpers — including divergent-id helpers no prefix rule can
  prove), driver/updater bundles in `/Library/Application Support` and
  `/Library/PrivilegedHelperTools`, each app's folder name, dot-prefix relations
  in both directions, and the label of every Launch Agent/Daemon whose program
  still exists — the same live/dead line `leftovers` draws. `com.apple.*` and
  the `group.*` namespace never surface at all (a group is a shared space, not
  an app's identity — though a proven orphan's group container still rides
  along). Vendor-NAME folders (`Application Support/Adobe`) can't be proved and
  are never auto-surfaced.
- **Honest noise floor:** an orphan appears in the picker only with a strong
  footprint (Containers / Application Support / Saved State) or ≥ 1 MB; the tiny
  lone-plist tail folds into one count line instead of drowning the list.
- **Guarded in reverse too:** `uninstall <bundle-id>` refuses an id that
  anything installed still claims, so it can never reach a live app's (or its
  helper's) data.

### Added — `tools` flags upgradable formulae, still offline

- Each Homebrew leaf that has a newer version is flagged inline with the exact
  command (`apfel  1.5.0  ↑ 1.8.3  brew upgrade apfel`), plus a summary line.
  This reads **brew's local index** (`brew outdated`, auto-update pinned off) —
  no network call is added; freshness is your last `brew update`, and the
  output says so. Delegation over reinvention: sheersweep points at the native
  upgrade path, it doesn't build an updater.

### Changed — Adobe leaves the sweep

- The sweep no longer touches `Application Support/Adobe` (and the v0.6.0
  "is Adobe installed?" guard is gone with it): vendor application data was
  never regenerable junk, and hard-coding one vendor into the sweep is exactly
  what the discovery above replaces. `Caches/Adobe` also loses its dedicated
  line — the sweep already clears all of `Library/Caches` wholesale, so it was
  a no-op subset. Net: **the sweep names no vendor**, and the never-touch list's
  Adobe carve-out disappears from `--help` (all nine locales), README,
  SECURITY.md, and AGENTS.md. Adobe residue now shows up where it belongs: as a
  discovered orphan in `uninstall`.

### Honest scope

- Discovery was tuned against a real, lived-in Mac: a live tablet driver's
  transient sandboxed XPC can own a container that appears in **no** scannable
  Info.plist or launchd label (observed: `com.wacom.Wacom-Display-Settings`,
  32 KB, while the driver runs). Such an id can still surface — with its size,
  its dimmed hint, and the typed-confirm + Trash + restore gate as the floor.
  Every claim rule errs toward *keeping*; the confirm gate covers what no scan
  can prove. SECURITY.md spells this out.

## [0.6.0]

### Pre-release hardening (multi-agent cold-read review)

- **Fixed: `uninstall <formula>` was dead on Apple Silicon.** After the sudo
  re-exec, `brew_locate` searched a sanitized PATH and couldn't see
  `/opt/homebrew/bin`, so every formula reported "no Homebrew." Now probes the
  two standard prefixes by absolute path first. The sweep's `brew cleanup`
  shared the same bug (silently skipped on Apple Silicon) and is fixed with it.
- **Fixed: the never-touch promise was violated for Adobe.** The sweep cleared
  `Application Support/Adobe` unconditionally — emptying a *live* Adobe install's
  licensing/settings — despite a comment and docs claiming "only if Adobe was
  uninstalled." Now gated by an actual "is any Adobe app still installed?" check;
  it's cleared only when Adobe is truly gone.
- **Hardened multi-account safety (root-run moves):** `to_trash` now refuses a
  `.Trash` that is a symlink or is owned by someone other than the home's owner —
  previously another local account could point its `~/.Trash` at a system dir and
  make our root-run `mv` write *through* the link, outside their home (reliably
  triggerable via `leftovers`). `restore` gets the same guard against a symlinked
  parent.
- **Consent-screen output injection closed:** cross-account filenames and plist
  values are now stripped of terminal control bytes (ESC/CSI) before being
  printed above the typed-confirm prompt, so a crafted name can't erase or forge
  what you're about to approve. New `vis()` helper; applied in `uninstall`,
  `leftovers`, and the picker.
- **AppleScript injection closed:** a crafted `CFBundleIdentifier` is no longer
  interpolated into the "quit the app" `osascript` — the bid is validated
  (`[A-Za-z0-9.-]` only) or the best-effort quit is skipped.
- **Localized the last English-only UI:** `restore --list` row count and the
  `(restored)` mark now render in all 9 locales (new `rs_list_count` /
  `rs_restored` keys). Picker: an invalid selection no longer prints a redundant
  "Cancelled" and now exits non-zero.
- **Docs made literally true:** the "never deletes except by moving to Trash"
  line now notes the one `rm` it makes — discarding an empty receipt it wrote
  itself, never your data.

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
- **Nine languages** — the interface now speaks en-US · ja-JP · zh-TW ·
  **zh-Hans** · ko-KR · es-ES · de-DE · fr-FR · pt-BR, auto-detected from the
  system locale. Simplified Chinese resolves to zh-Hans instead of the old
  English fallback; zh-HK joins zh-TW, zh-SG joins zh-Hans. All languages ship
  **inside the single script** — a consent prompt must never depend on a
  download — and a func-test extracts every `t()` key from the script itself
  and enforces all nine locales per key, so a future string can't silently
  fall back for one language.
- **i18n is tiered**: consent/judgment sentences are fully localized; command
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
