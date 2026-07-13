# Spec: reclaiming build artifacts

**Status:** Shipped in v0.8.0 (2026-07-13), as designed — kept as the design
record. The open questions below were resolved at build time: explicit roots
list (+ CLI path override), top-most candidate wins (find prunes at a match),
and a distinct `kind=reclaim` receipt whose rebuild commands `restore` surfaces.
**Scope:** Add the ability to reclaim space from *build output* (regenerable
artifacts a build tool produces), without betraying the trust rules that make
sheersweep the opposite of a black-box cleaner.

## The problem

Build output is some of the heaviest junk on a developer's Mac — Swift
`.build`, `node_modules`, `target`, `dist`, `.next` — easily tens of GB across a
dozen repos. It is also genuinely regenerable: one command rebuilds it. So it
*looks* like a perfect fit for a cleaner.

It is also exactly where every other cleaner loses trust: to find it, the tool
has to walk *into your project directories* and delete things. Get the
heuristic slightly wrong and it removes a folder named `dist` that was actually
your data. That is the CleanMyMac failure mode this project exists to refute.

So the answer is not "add build dirs to the sweep." It is two layers, drawn
along the line the sweep already refuses to cross.

## Two layers

### Layer 1 — regenerable caches in fixed cache locations → fold into the sweep

These live at well-known, unambiguous cache paths. Their meaning is not in
doubt and no project-directory walking is required. The sweep already does this
class (`~/.npm`, Xcode `DerivedData`, Cargo/Gradle caches). Additions in the
same spirit, low ceremony, no new verb:

- `$TMPDIR/node-compile-cache` — Node's V8 compile cache (regenerated on next run)
- `~/Library/Caches/pytest`, `.pytest_cache` under cache roots
- `~/Library/Caches/Homebrew` (already covered by `brew cleanup`)
- any other tool cache that lives under a `Caches`/`.cache` root, not inside a repo

These belong to the existing `clean()` path against fixed roots. Same dry-run,
same never-touch list, same multi-account pass. Nothing about Layer 1 changes
the trust story.

### Layer 2 — build output *inside project directories* → a new, opt-in verb

This is the valuable, dangerous part. It gets its own deliberate verb —
`reclaim` — exactly as `uninstall` and `leftovers` are separate verbs and are
never folded into the sweep. The default sweep must keep its promise from the
README ("never grow aggressive or deep modes that rummage through app data").

```bash
sheersweep reclaim                 # scan, preview grouped by repo, confirm
sheersweep reclaim --dry-run       # preview only
sheersweep reclaim --stale 30d     # only artifacts whose repo hasn't been touched in 30 days
```

## The three gates (what makes a directory eligible)

A candidate is flagged **only when all three are true**. Any one alone is not
enough — the conjunction is what lets us say "this is regenerable output, not
your data":

1. **Ignored by git.** The path is matched by the repo's `.gitignore`
   (`git -C <repo> check-ignore <path>` succeeds). Build output is virtually
   always ignored; your data virtually never is.
2. **Matches a known build pattern.** Directory name is one of a fixed,
   readable allow-list: `.build`, `node_modules`, `target`, `dist`, `.next`,
   `build`, `.gradle`, `Pods`, … (kept short and auditable, like the
   never-touch list).
3. **A sibling manifest proves the build tool.** The parent directory contains
   the corresponding manifest — `Package.swift`/`.xcodeproj` for `.build`,
   `package.json` for `node_modules`/`dist`/`.next`, `Cargo.toml` for `target`,
   `Podfile` for `Pods`. No manifest → not eligible, no matter the name.

Gate 3 is the one that saves the user who has a content folder literally named
`dist`: without a `package.json` beside it, it is invisible to `reclaim`.

The never-touch list still applies on top: anything under Photos/Documents/
Desktop, any Obsidian vault, any cloud-sync folder is excluded even if it
somehow passed the gates.

## Every candidate carries its provenance (shared data model)

This is the unifying idea: `uninstall`, `leftovers`, and `reclaim` are all the
same primitive — *surface a removable set, each item with its provenance and
its undo, get consent, remove*. They differ only in their **finder**. Every
candidate, regardless of finder, has the same shape:

```
{ path, size, why_safe, undo, last_touched }
```

| finder      | why_safe                          | undo                       |
|-------------|-----------------------------------|----------------------------|
| uninstall   | "belongs to <app>, bundle id …"   | restore from Trash         |
| leftovers   | "launches a binary that is gone"  | restore from Trash         |
| reclaim     | "gitignored + build pattern + manifest" | rebuild (`swift build` / `npm install`) — *or* restore from Trash |

The preview is the anti-CleanMyMac payload made concrete. CleanMyMac says
"Junk — 3.8 GB — Clean." sheersweep says:

```
snapsift/app/.build      773 MB   rebuild: swift build      (14 days untouched)
motifmint/node_modules   261 MB   rebuild: npm install      (31 days untouched)
```

It tells you what it is, how to undo it, and how stale it is — so *you* judge
alive vs dead. The machine never decides a repo is "done."

## Delete policy: reclaim moves to the Trash, like every other verb

`reclaim` removes through the Trash and writes a receipt, exactly as `uninstall`
and `leftovers` do. **One promise, no asterisk:** the only operations that
delete anything move files to the Trash, and `restore` puts them back. That
single sentence stays true and auditable — which is worth more than any
optimization that would force a footnote onto the headline trust claim.

An earlier draft argued `reclaim` should use `rm` (the three gates prove the
bytes are regenerable, so the "real" undo is a rebuild, not file recovery). That
argument does not survive contact with how APFS actually works:

- Each volume's `~/.Trash` sits on the **same APFS data volume** as the project.
  Moving a build dir there is an **instant rename**, not a 690 MB copy — it does
  not duplicate or temporarily double the space.
- Space is reclaimed when the Trash is emptied — the **same one-step model the
  README already documents** for `uninstall` ("Emptying the Trash is what
  finally reclaims the space"). No new mental model.
- Trashing ~50k files is a rename of the *top directory*, not a per-file move.
  Emptying it later unlinks the inodes — exactly what `rm` would have done
  anyway. There is no speed win to trade trust for.

So the only real benefits `rm` offered (fast, doesn't hog space) are things a
same-volume Trash rename already gives for free. Spending the headline promise
to buy them would be paying for nothing.

**The regenerability still matters — it just shapes the undo, not the delete.**
The receipt records the **rebuild command as the recommended undo**, so after a
reclaim the user has two paths:

- `npm install` / `swift build` / `cargo build` — rebuild a clean tree
  (recommended; avoids any lockfile drift a Trashed tree might carry), and
- restore the files from the Trash (the safety net, identical to every other
  verb).

`sheersweep restore` after a reclaim restores the files like any other restore,
and additionally prints the rebuild commands as the cleaner alternative. Two
undos, one consistent promise.

## Staleness filter

`--stale <duration>` (e.g. `7d`, `30d`) shows only artifacts whose repo's most
recent source change is older than the threshold (newest mtime of tracked files,
or last commit). This turns `last_touched` from a displayed column into an
active filter and is the safest high-value mode:

> "reclaim everything not touched in 30 days"

is a sentence a user can trust, and it removes the need for the machine to guess
which repo is "mature" — it uses an objective signal (how long since you touched
it) and leaves the call with the user.

## UX rules (non-negotiable)

- **Never folded into the sweep.** A separate verb, invoked on purpose.
- **Dry-run honoured.** `reclaim --dry-run` deletes nothing.
- **Preview grouped by repo**, with per-item size, rebuild command, staleness,
  and a grand total — then a typed confirmation, as `uninstall` does.
- **Per-item / per-category opt-in.** Selectable; never a single blind "reclaim
  all." (This is why feelreef was kept while motifmint was cleared in the
  session that motivated this spec — that call is the user's, not the tool's.)
- **Same multi-account, same never-touch list, same readable allow-lists.**

## Architecture

```
finders:   uninstall-finder   leftovers-finder   reclaim-finder (3 gates)
                     \               |               /
                      v              v              v
              candidate model { path, size, why_safe, undo, last_touched }
                                     |
                     present  ->  consent  ->  remove
              (grouped preview)  (typed)        (to_trash, all verbs)
```

`reclaim` reuses the existing preview/confirm/`to_trash()`/receipt/restore
machinery almost wholesale (`pick`-style selection, `receipt_*`, `do_restore`)
and adds only:

- `reclaim_scan()` — walk candidate repos, apply the three gates, emit the model
- a receipt field carrying the **rebuild command**, so `restore` can offer
  rebuild as the recommended alternative to restoring the files

## Open questions

- **Where to scan.** A configured roots list (e.g. `~/Developer`) vs walking all
  of `$HOME` minus never-touch. Leaning toward an explicit roots list to keep it
  fast and predictable.
- **Monorepo nesting.** Report the top-most eligible dir only, or each nested
  `node_modules`? Probably top-most, with total size rolled up.
- **`restore` semantics after reclaim.** Restores files from the Trash like any
  other verb, and additionally prints the rebuild commands as the recommended
  alternative. Worth a distinct receipt type so `restore` knows to surface the
  rebuild hint for a reclaim.
```
