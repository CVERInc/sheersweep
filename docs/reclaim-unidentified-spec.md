# Spec: reclaim's "unidentified" tier

**Status:** Shipped in v0.10.0 (2026-07-22) — kept as the design record.
**Scope:** Let `reclaim` surface the heavy folders it *cannot* prove are
regenerable — without turning into the black-box cleaner sheersweep exists not
to be. Extends [`reclaim-spec.md`](reclaim-spec.md); the proven tier there is
unchanged.

## The problem the three gates create

`reclaim`'s three gates (gitignored + known name + sibling manifest) are
deliberately conservative: everything they surface is *provably* regenerable, so
the list is safe to clear in one batch. But conservatism has a cost — a blind
spot. The folder that actually balloons a disk is often the one the gates
*can't* prove: a big gitignored crawl, an export, a downloaded model cache, with
no manifest and an off-list name. It fails gate ② and/or ③, so it stays
invisible and is never offered. Hiding the fat unprovable folder is the one
thing a cleaner you trust shouldn't do — the person who knows what it is never
gets asked. (Born from a real 6.5 GB `.harvest` crawl dir that sat invisible
while `reclaim` swept the small provable stuff around it.)

## The insight: it's one model, not two

"regenerable" (reclaim) and "reinstallable" (uninstall) are the same idea with
the same tail risk — both assume the *source* still exists (registry up, vendor
alive, site still crawlable), an assumption that can always break. So nothing
sheersweep removes is truly certain to come back. What actually carries the
safety is not the proof; it's **Trash-not-rm + the human decides**. Once you see
that, "provable vs unprovable" stops being a wall and becomes a *confidence*
dimension in one list. A file doesn't remember how it was made — provenance
isn't in the bytes; convention (a manifest) is humanity bolting the proof onto
the artifact, and most regenerable things carry no such proof. The tool can
prove neither "safe" nor "dangerous" for those — it simply doesn't know.

## The design

One verb, one scan, one list, two tiers by confidence:

| tier | gates | confirmation | receipt |
|------|-------|--------------|---------|
| **proven** (unchanged) | gitignored + known name + manifest | typed **count** → batch | rebuild command per folder |
| **unidentified** (new) | gitignored + heavy + cold, minus what proven already listed | per-item typed **name** (uninstall-style) | recorded; no rebuild recipe (honest) |

Rules that keep it honest:

1. **Two gate-sets feed one list.** Proven = 3 gates. Unidentified = gitignored
   (via `git status --ignored`, which collapses a wholly-ignored dir to one
   entry — a 6 GB tree costs one `stat`, not a walk) + heavy (≥512 MB, override
   `SHEERSWEEP_SUSPECT_MIN_MB`) + cold (honours `--stale`), minus any path the
   proven scan already claimed. Signal-narrowed, just without the manifest.
2. **What git was never told to ignore is never offered.** The tier reads only
   `!!` (ignored) rows — never `??` (untracked), which could be unsaved work.
   This is the safety line, and it has a regression test.
3. **Friction scales with confidence.** Proven rides the typed-count batch.
   Unidentified must NOT — each is confirmed by typing its own name. Cost-if-
   wrong is asymmetric: mis-trashing `node_modules` is a two-minute reinstall;
   mis-trashing a 6 GB unidentified dir you then empty-from-Trash-for-space could
   be gone for good. And the Trash net is *weakest* exactly for the fat items
   (you empty it fast to reclaim the space). More friction where the net is
   thinnest.
4. **Label is "unidentified", never "dangerous".** The tool can't prove
   regenerable *or* dangerous — it doesn't know. Unlike `uninstall` (which
   positively IDs residue via a bundle-id catalog), this tier can't attribute the
   folder to anything, so it says exactly that. Crying "dangerous" on harmless
   scratch trains the user to ignore the warning — worse than honest ignorance.
5. **Same safety net.** Moves to the Trash, lands in the same `kind=reclaim`
   receipt, undone by `restore`. The receipt carries no rebuild line for these —
   honestly, since that's why they were unidentified.

## The cost paid honestly

`reclaim`'s old promise — "three proofs, else invisible" — was written down and
trusted. Behaviour and words moved together: the 9-language help, `AGENTS.md`,
`README.md`, and this doc all now say `reclaim` surfaces the unprovable heavy
folders for you to judge, rather than hiding them. A cleaner that says one thing
and does another is the exact black box this tool refuses to be.

## What did NOT change

- The default **sweep** and its promise (`AGENTS.md` rule 3, "never grow an
  aggressive/deep mode") — this is reclaim-only.
- The **never-touch** list (an Obsidian vault ancestor still skips a candidate).
- The **proven** tier: still three gates, still the typed-count batch, still a
  recorded rebuild command.
- Trash-not-rm; dry-run-first; the confirmation prompts still read a TTY for the
  human — never auto-confirmed.
