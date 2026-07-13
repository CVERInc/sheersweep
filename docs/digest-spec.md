# Spec: the sweep digest — one habitual command surfaces everything

**Status:** Shipped in v0.9.0 (2026-07-13, same day as the lock) — kept as the
design record. One amendment from the build: "skipped silently" gained a short
**bounded grace** (a few seconds, usually zero) before skipping — a mostly-empty
digest on a fast `--dry-run` (the recommended first run!) would have defeated
the feature; a bounded wait is not a stall.

## The problem: the best verbs live in the rarest moments

A cleaner gets reached for in exactly three moments: disk-full panic, the
periodic hygiene ritual, and "I'm removing this app." Whichever tool owns a
person's *moment* owns their one cleaner slot — and it is the habitual moment
(the plain `sheersweep` run) that builds muscle memory.

sheersweep's strongest finds — data left behind by removed apps (`uninstall`'s
🧟 discovery), gigabytes of rebuildable build output (`reclaim`), upgradable
formulae (`tools`) — live in *low-frequency* verbs. Low-frequency means
forgotten. The digest hangs them on the high-frequency moment.

## The one idea

At the end of every sweep (real or `--dry-run`), print a short digest of what
the *other* verbs can see right now — **numbers and pointers only, nothing is
touched**:

```
Also seen on this Mac:
   🧟 24 removed apps left 1.6G of data behind   → sheersweep uninstall
   ♻️ 4.5G of rebuildable build output           → sheersweep reclaim
   ↑ 4 Homebrew formulae have updates            → sheersweep tools
   🤖 AI session archives hold 2.1G              → your AI tool's own cleanup
```

Each line names its verb; the digest never acts. This is the same soul as
`tools` (see, point, don't delete) and the same boundary already drawn for AI
session data: sheersweep may *report* what a domain-owning tool should clean,
and must send the person to that tool.

## Rules (non-negotiable)

- **Report only.** The sweep's contract — "clears only the regenerable junk on
  its fixed list" — is untouched. The digest adds zero deletion surface.
- **No perceptible slowdown.** The discovery/reclaim/outdated scans run in the
  background *while* the sweep works (the 0.7.2 picker pattern: hide the wait
  under work that is already happening). Any scan that hasn't finished by
  digest time is skipped silently — a missing line, never a stall.
- **Honest numbers.** Each line is a point-in-time measurement produced by the
  same finder its verb uses — never an estimate, never a scare figure. If a
  finder found nothing, its line simply doesn't appear; an empty digest prints
  nothing at all.
- **Offline stays offline.** The ↑ line reads brew's local index only, exactly
  as `tools` does.
- **The AI-sessions line points away from sheersweep.** Session archives are
  conversation history — not regenerable, never sheersweep's to touch. Report
  the size, point at the owning tool, stop. (Boundary decided 2026-07-11.)

## Shape

- Fires after the sweep's snapshot section, before the closing free-space line.
- Localized in all nine languages (the counts/sizes/verb names stay raw).
- No new flags. The digest is part of what a sweep *is* now; people who script
  sweeps get it on stdout like everything else.

## Why this is the answer to "users keep only one cleaner"

The one-cleaner slot is won at the trigger moment, not on the feature table.
The digest makes the single habitual command demonstrate, on every run, the
things only this tool can see — so the rare verbs stop depending on memory,
and the tool argues for its own slot with evidence instead of marketing.
