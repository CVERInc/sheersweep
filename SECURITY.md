# Security model

sheersweep deletes things on your Mac, as root, across every account. That is
exactly the kind of tool that should show its work. This document is the safety
model in plain terms — what sheersweep will and won't do, and why. It matches the
code; if you find a place where it doesn't, that's a bug worth reporting (see the
bottom).

## The one-sentence version

sheersweep never deletes a file of *yours* except by moving it to the Trash, and
every other destructive action is a tool's **own** uninstaller, printed verbatim
before it runs and only after you type a confirmation.

## What can delete, and what can't

The whole script has a small, findable destructive surface. Read these and you've
read the risk:

1. **The sweep's `find … -delete`** runs *only* on the fixed cache/log/temp paths
   listed in `--help` (`Library/Caches`, `Library/Logs`, `~/.cache`, `~/.npm`,
   Xcode `DerivedData`/`DeviceSupport`, CoreSimulator/Cargo/Gradle caches,
   `/Library/Caches`, `/.adobeTemp`). These are regenerable — the OS and your apps
   rebuild them. There is no "aggressive" or "deep" mode, and there never will be.

2. **`uninstall` / `leftovers` move to the Trash** — they call `mv` into the
   owning account's `~/.Trash`, never `rm`. Every move is recorded in a plain-text
   receipt under `~/.sheersweep/uninstalls/`, so `sheersweep restore` puts the
   entire last removal back. Emptying the Trash — the only irreversible step — is
   always your own deliberate action.

3. **Delegated uninstallers.** A Homebrew formula is removed by running
   `brew uninstall <name>` — the tool's own uninstaller — which sheersweep prints
   in full and runs only after you type the formula's name. sheersweep itself does
   not `rm` your data to do this. (`brew cleanup` in the sweep works the same way.)

The only `rm` sheersweep itself makes is discarding an empty receipt file it just
wrote — never your data.

## The never-touch list is unreachable by construction

No line in the script can reach: Photos / Documents / Desktop / Movies / Music,
Clip Studio (CELSYS), app Containers & Application Support (except an
already-uninstalled Adobe's leftovers — gated by an actual "is Adobe still
installed?" check, so a live install's data is never cleared), Dropbox / cloud-sync
folders, screen recordings, Mail / Messages / Keychains, any git repo, any
Obsidian vault. The sweep operates on a hard-coded path list; it does not walk your
home looking for things to delete.

## `uninstall` matches by identity, never by a fuzzy name

An app's footprint is found by its **bundle identifier** (plus the exact
display-name paths macOS itself uses), never a substring match — so uninstalling
"Notes" can't sweep up "Notability". A Homebrew formula is matched by brew's own
receipt; a hand-installed bare binary by exact filename in `~/bin` / `~/.local/bin`
/ `/usr/local/bin` (symlinks owned by Homebrew or an `.app` are never touched —
their owners uninstall them). Apps on the sealed system volume (`/System/*`) and
the firmlinked Safari are refused.

## Multi-account hardening

sweep and uninstall run as root and touch every account under `/Users`. Because
one account's files (and its `~/.Trash`) are controlled by *that* account, a
hostile local user is part of the threat model. The following guards exist
specifically for that case:

- **Trash can't be redirected.** Before moving anything into an account's
  `~/.Trash`, sheersweep refuses it if it's a symlink or is owned by anyone other
  than that account's owner — otherwise a user could point their own `~/.Trash` at
  a system directory and make sheersweep's root-run `mv` write *through* the link,
  outside their home. `restore` has the same guard against a symlinked parent.
  (Residual: a same-account swap in the sub-millisecond window between the check
  and the move is a race, not the trivial static redirect it would otherwise be.)

- **The consent screen can't be forged.** File names and plist values from another
  account are stripped of terminal control bytes (ESC / CSI) before being printed
  above the confirmation prompt, so a crafted name can't erase or fake what you're
  about to approve.

- **No injection through metadata.** A crafted `CFBundleIdentifier` is validated
  (`[A-Za-z0-9.-]` only) before it's ever passed to the "quit the app" AppleScript;
  anything unusual skips the best-effort quit rather than risk running as you.

## No network, no telemetry, no daemon

sheersweep makes no network calls, runs no background process, and phones nothing
home. Homebrew invocations pin `HOMEBREW_NO_AUTO_UPDATE=1` so even delegated brew
commands stay offline. `--version`, `--help`, and the read-only `tools` inventory
never escalate and never need a password.

## Honest scope

- sheersweep guarantees the *files it moves* are recoverable from the Trash and
  that its own logic can't reach the never-touch list. It cannot guarantee an app
  it removed left nothing anywhere a name-based match can't safely see — where that
  applies (a bare binary's data directory), it says so out loud rather than guess.
- The multi-account guards above reduce the demonstrated attacks to races or
  refusals; they are the honest bound a shell script running as root can enforce,
  not a claim of formal isolation. On a single-user Mac none of this applies.

## Reporting a vulnerability

Found a way to make sheersweep delete or write something it shouldn't, or a place
where this document overclaims what the code does? Please report it privately:
open a [GitHub security advisory](https://github.com/CVERInc/sheersweep/security/advisories/new)
or email **security@cver.net**. A single readable script means fixes ship fast.
