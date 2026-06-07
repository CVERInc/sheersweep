# sheersweep

[![CI](https://github.com/CVERInc/sheersweep/actions/workflows/ci.yml/badge.svg)](https://github.com/CVERInc/sheersweep/actions/workflows/ci.yml)

**English** · [日本語](./README.ja.md) · [繁體中文](./README.zh-TW.md)

> The Mac cleaner you can **read**. Open source · dry-run first · a hard never-touch list · sweeps every account.

Most Mac cleaners are a black box that asks you to *trust* them while they delete
things you can't see, behind a subscription, with a little fear in the marketing.
`sheersweep` is the opposite: it's **one short shell script you can read end to
end**, it **shows you exactly what it will free before it frees anything**, it
**only clears caches/temp/logs the OS rebuilds on its own**, and it has a
**hard-coded list of things it will never touch**.

The honest cleaner. No subscription, no scare tactics, no surprises.

## Why trust it

- **You can read every line.** It's ~150 lines of `bash`. The dangerous verb
  (`find … -delete`) appears in exactly one helper, on exactly the paths listed below.
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

## Install & use

```bash
git clone https://github.com/CVERInc/sheersweep.git
cd sheersweep

./sheersweep --dry-run   # preview — deletes nothing (recommended first run)
./sheersweep             # real run (prompts once for sudo — needed to sweep all accounts)
./sheersweep --version
./sheersweep --help
```

Prefer a double-click? Copy it to your Desktop and rename to `sheersweep.command`,
or symlink onto your `PATH`:

```bash
ln -s "$PWD/sheersweep" /usr/local/bin/sheersweep
```

Sweeping every account needs admin rights, so sheersweep re-runs itself with
`sudo` (one password prompt). `--version` / `--help` never need it.

## Scope, on purpose

sheersweep deliberately clears **only** the safe, regenerable stuff. It will not
grow "aggressive" or "deep" cleaners that hunt through app data — that's exactly
where cleaners delete something you wanted, and it's the opposite of the trust
this tool is built on. Narrow and honest beats broad and scary.

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
