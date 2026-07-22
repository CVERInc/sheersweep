#!/usr/bin/env bash
# Functional tests for the uninstall/restore machinery.
#
# These source `sheersweep` as a LIBRARY (SHEERSWEEP_LIB=1) to reach the pure
# move/receipt/restore functions WITHOUT escalating to sudo or running a sweep,
# then exercise them inside a throwaway sandbox under a temp dir. Each test is a
# regression guard for a specific edge bug (tab/newline paths, same-second Trash
# collisions, mkdir-failure surfacing, cross-fs restore, symlinked/odd-named
# apps, the receipt's NUL framing, and the concurrent-restore claim).
#
# macOS only (uses `stat -f`, the macOS find/sort). Run via scripts/test.sh.
set -u

HERE="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$HERE/sheersweep"

# --- source as a library: define functions, run nothing -----------------------
# These are read by the sourced library / its functions, not by this file directly.
# Pin the UI language to en-US so the string assertions below are deterministic
# regardless of the test machine's locale (the script resolves SS_LANG from
# SHEERSWEEP_LANG at source time).
export SHEERSWEEP_LANG="en-US"
# shellcheck disable=SC2034
DRY=0
# shellcheck disable=SC2034
RESTORE_LIST=0
# shellcheck disable=SC2034
SHEERSWEEP_LIB=1
# shellcheck source=/dev/null
source "$SCRIPT"

fails=0
pass() { printf '  ✅ %s\n' "$1"; }
fail() { printf '  ❌ %s\n' "$1"; fails=$((fails + 1)); }

SBX=""
setup() { SBX="$(mktemp -d "${TMPDIR:-/tmp}/sheersweep-test.XXXXXX")"; }
teardown() { [ -n "$SBX" ] && rm -rf "$SBX"; SBX=""; }

# ------------------------------------------------------------------------------
echo "→ func-test (uninstall/restore edge cases)"

# (3) Trash collision: trashing two DIFFERENT items that share a basename within
# the same wall-clock second must keep BOTH — a coarse second-stamp would clobber
# the first. We move three same-named files back to back; all three must survive.
setup
mkdir -p "$SBX/a" "$SBX/b" "$SBX/c"
echo A > "$SBX/a/Cache"; echo B > "$SBX/b/Cache"; echo C > "$SBX/c/Cache"
HOME_OWNER="$SBX/home"; mkdir -p "$HOME_OWNER"
to_trash "$SBX/a/Cache" "$HOME_OWNER"; d1="$TRASH_DEST"
to_trash "$SBX/b/Cache" "$HOME_OWNER"; d2="$TRASH_DEST"
to_trash "$SBX/c/Cache" "$HOME_OWNER"; d3="$TRASH_DEST"
n_in_trash="$(find "$HOME_OWNER/.Trash" -type f | wc -l | tr -d ' ')"
if [ "$n_in_trash" -eq 3 ] && [ -n "$d1" ] && [ -n "$d2" ] && [ -n "$d3" ] \
   && [ "$d1" != "$d2" ] && [ "$d2" != "$d3" ] && [ "$d1" != "$d3" ]; then
  pass "same-second Trash collisions keep all 3 (unique dests)"
else
  fail "same-second Trash collision lost an item (n=$n_in_trash)"
fi
teardown

# (10) Recreated .Trash must be 0700 (a Trash other users can read is wrong).
setup
HOME_OWNER="$SBX/home"; mkdir -p "$HOME_OWNER"
echo x > "$SBX/item"
to_trash "$SBX/item" "$HOME_OWNER"
mode="$(stat -f %Lp "$HOME_OWNER/.Trash" 2>/dev/null)"
if [ "$mode" = "700" ]; then
  pass "recreated .Trash is mode 0700"
else
  fail "recreated .Trash mode is $mode (want 700)"
fi
teardown

# (2) Receipt must round-trip a path containing a TAB and a NEWLINE. We hand-build
# a receipt the way do_uninstall writes it (header, NUL sentinel, NUL pairs) with
# nasty paths, then confirm the readers recover EXACTLY those paths.
setup
rfile="$SBX/receipt.tsv"
dest_a="$SBX/.Trash/we$(printf '\t')ird"          # TAB in the path
orig_a="$SBX/orig/we$(printf '\t')ird"
dest_b="$SBX/.Trash/two
line"                                              # NEWLINE in the path
orig_b="$SBX/orig/two
line"
{
  echo "# sheersweep uninstall receipt"
  echo "# app=My App"
  echo "# bid=com.test.app"
  echo "# date=20260616-000000"
  echo "# format=nul-pairs"
  printf '\0'
  printf '%s\0%s\0' "$dest_a" "$orig_a"
  printf '%s\0%s\0' "$dest_b" "$orig_b"
} > "$rfile"
got_app="$(receipt_header "$rfile" app)"
got_bid="$(receipt_header "$rfile" bid)"
got_count="$(receipt_count "$rfile")"
# read the data back the same way do_restore does
declare -a got_dest got_orig
while IFS= read -r -d '' d && IFS= read -r -d '' o; do
  got_dest+=("$d"); got_orig+=("$o")
done < <(receipt_data "$rfile")
if [ "$got_app" = "My App" ] && [ "$got_bid" = "com.test.app" ] \
   && [ "$got_count" = "2" ] && [ "${#got_dest[@]}" -eq 2 ] \
   && [ "${got_dest[0]}" = "$dest_a" ] && [ "${got_orig[0]}" = "$orig_a" ] \
   && [ "${got_dest[1]}" = "$dest_b" ] && [ "${got_orig[1]}" = "$orig_b" ]; then
  pass "receipt round-trips TAB and NEWLINE paths + reads header/count"
else
  fail "receipt mangled a TAB/NEWLINE path (app=$got_app count=$got_count n=${#got_dest[@]})"
fi
teardown

# (2/6) End-to-end restore of a tab-named item via do_restore, including a
# cross-directory mkdir of the parent — the item must land back exactly.
setup
REAL_HOME="$SBX/home"
mkdir -p "$REAL_HOME/.sheersweep/uninstalls"
tab="$(printf '\t')"
trashed="$REAL_HOME/.Trash/odd${tab}name"
orig="$SBX/restored/deep/odd${tab}name"
mkdir -p "$REAL_HOME/.Trash"; echo payload > "$trashed"
rfile="$REAL_HOME/.sheersweep/uninstalls/20260616-000001-com.test.app.tsv"
{ echo "# app=Odd"; echo "# bid=com.test.app"; echo "# date=20260616-000001"; printf '\0'
  printf '%s\0%s\0' "$trashed" "$orig"; } > "$rfile"
printf 'y\n' | do_restore >/dev/null 2>&1
if [ -f "$orig" ] && [ "$(cat "$orig")" = "payload" ] && [ -f "$rfile.restored" ]; then
  pass "do_restore puts a TAB-named item back and marks receipt restored"
else
  fail "do_restore failed on TAB-named item (orig exists: $([ -f "$orig" ] && echo y || echo n))"
fi
teardown

# (1) mkdir-failure must SURFACE (stderr + non-zero) instead of silently skipping.
# Force failure by making the parent path a FILE so mkdir -p can't create a dir.
setup
REAL_HOME="$SBX/home"
mkdir -p "$REAL_HOME/.sheersweep/uninstalls" "$REAL_HOME/.Trash"
echo data > "$REAL_HOME/.Trash/thing"
blocker="$SBX/blocked"; : > "$blocker"          # a regular file in the way
orig="$blocker/cant/be/made"                     # mkdir -p will fail here
rfile="$REAL_HOME/.sheersweep/uninstalls/20260616-000002-com.test.app.tsv"
{ echo "# app=Blk"; echo "# bid=com.test.app"; echo "# date=20260616-000002"; printf '\0'
  printf '%s\0%s\0' "$REAL_HOME/.Trash/thing" "$orig"; } > "$rfile"
# Single invocation: capture stderr to a file, and the exit code, together.
errf="$SBX/err.txt"
rc_marker=0
printf 'y\n' | do_restore >/dev/null 2>"$errf" || rc_marker=$?
err="$(cat "$errf")"
if printf '%s' "$err" | grep -q "could not restore" && [ "$rc_marker" -ne 0 ]; then
  pass "restore mkdir failure surfaces (stderr + non-zero exit)"
else
  fail "restore mkdir failure was swallowed (rc=$rc_marker err=[$err])"
fi
teardown

# (9) Concurrent restore: the receipt is CLAIMED atomically (renamed out of the
# *.tsv glob) BEFORE any file is touched, so two racing restores can't both work
# it. We assert the claim post-condition directly: after a restore there is no
# claimable *.tsv left (only *.restored), and a second restore right after finds
# nothing — proving the claim, not just end-of-run cleanup.
setup
REAL_HOME="$SBX/home"
mkdir -p "$REAL_HOME/.sheersweep/uninstalls" "$REAL_HOME/.Trash"
echo z > "$REAL_HOME/.Trash/z"
rfile="$REAL_HOME/.sheersweep/uninstalls/20260616-000003-com.test.app.tsv"
{ echo "# app=Z"; echo "# bid=com.test.app"; echo "# date=20260616-000003"; printf '\0'
  printf '%s\0%s\0' "$REAL_HOME/.Trash/z" "$SBX/zland/z"; } > "$rfile"
printf 'y\n' | do_restore >/dev/null 2>&1
leftover_tsv="$(find "$REAL_HOME/.sheersweep/uninstalls" -name '*.tsv' | wc -l | tr -d ' ')"
out2="$(printf 'y\n' | do_restore 2>&1)"
if [ "$leftover_tsv" -eq 0 ] && printf '%s' "$out2" | grep -q "Nothing to restore" \
   && [ -f "$rfile.restored" ] && [ -f "$SBX/zland/z" ]; then
  pass "restore claims the receipt (no claimable *.tsv left; second run is a no-op)"
else
  fail "concurrent restore did not claim the receipt (leftover=$leftover_tsv out=[$out2])"
fi
teardown

# (5) Picker/uninstall tolerate symlinked + special-char app names. We can't run
# the full picker (it reads stdin and scans /Applications), but we CAN verify the
# building block: a NUL-safe find of an app whose name has a space and a symlink
# to it both resolve via the same `[ -d ]`-validated read used by pick_app.
setup
appdir="$SBX/Apps"; mkdir -p "$appdir"
real="$appdir/My Cool App.app"; mkdir -p "$real/Contents"
ln -s "$real" "$appdir/Linked App.app"
declare -a found
while IFS= read -r -d '' p; do
  [ -d "$p" ] || continue
  found+=("$p")
done < <(find "$appdir" -maxdepth 2 -name '*.app' -not -path '*.app/*' -print0 2>/dev/null | sort -z)
hit_space=0; hit_link=0
for p in "${found[@]}"; do
  [ "$p" = "$real" ] && hit_space=1
  [ "$p" = "$appdir/Linked App.app" ] && hit_link=1
done
# Guard against regressing to the old `-type d` scan, which silently DROPS the
# symlinked .app (a symlink is type l, not d): assert the new name+[-d] scan keeps
# strictly more than -type d would here.
typed_link="$(find "$appdir" -maxdepth 2 -type d -name '*.app' -not -path '*.app/*' 2>/dev/null | grep -c 'Linked App.app')"
if [ "$hit_space" -eq 1 ] && [ "$hit_link" -eq 1 ] && [ "$typed_link" -eq 0 ]; then
  pass "find sees spaced-name app AND symlinked .app (the old -type d scan misses the symlink)"
else
  fail "picker scan missed spaced/symlinked app (space=$hit_space link=$hit_link typedDrop=$typed_link)"
fi
teardown

# (5b) resolve_app's case-insensitive fallback must resolve a SYMLINKED .app that
# lives one folder deep (so the exact depth-1 path check misses it and the find
# fallback is the only path that can match). The old fallback used -type d, which
# skips a symlink → the app was unresolvable. Point REAL_HOME at the sandbox.
setup
REAL_HOME="$SBX/home"; mkdir -p "$REAL_HOME/Applications/Suite 2.0"
realapp="$SBX/store/Weird Name.app"; mkdir -p "$realapp/Contents"
ln -s "$realapp" "$REAL_HOME/Applications/Suite 2.0/Weird Name.app"   # symlink, depth 2
RESOLVED_APP=""
resolve_app "Weird Name"
if [ -n "$RESOLVED_APP" ] && [ -d "$RESOLVED_APP" ]; then
  pass "resolve_app fallback resolves a symlinked, subfolder-nested .app"
else
  fail "resolve_app missed the symlinked nested app (RESOLVED_APP=[$RESOLVED_APP])"
fi
teardown

# (L1) leftovers classification: lf_scan must sort launchd plists into DEAD (the
# launched binary is gone), REVIEW (interpreter that references a now-missing
# /Applications app), and KEPT (program exists, OR Apple's own job, OR an
# interpreter with no app refs). This is the honest brain — a working updater must
# never land in DEAD/REVIEW. We feed five synthetic plists and check the buckets.
setup
AG="$SBX/agents"; mkdir -p "$AG"
# a) DEAD — Program points to a binary that doesn't exist (note: $SBX expands).
cat > "$AG/com.test.dead.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.test.dead</string>
<key>Program</key><string>$SBX/gone/nope-binary</string>
</dict></plist>
PLIST
# b) REVIEW — /bin/bash referencing a missing /Applications app.
cat > "$AG/com.test.review.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.test.review</string>
<key>ProgramArguments</key><array>
<string>/bin/bash</string><string>-c</string>
<string>test -d "/Applications/Definitely Gone 9000.app"</string>
</array></dict></plist>
PLIST
# c) KEPT — Program exists (/bin/ls), so it's a live item, not junk.
cat > "$AG/com.test.live.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.test.live</string>
<key>Program</key><string>/bin/ls</string>
</dict></plist>
PLIST
# d) KEPT — Apple's own job is skipped BEFORE the dead check, even with a missing
# program (proves com.apple.* is never flagged).
cat > "$AG/com.apple.something.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.apple.something</string>
<key>Program</key><string>/nonexistent/apple/thing</string>
</dict></plist>
PLIST
# e) KEPT — interpreter with NO /Applications references → can't call it junk.
cat > "$AG/com.test.quiet.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
<key>Label</key><string>com.test.quiet</string>
<key>ProgramArguments</key><array><string>/bin/bash</string><string>-c</string><string>echo hi</string></array>
</dict></plist>
PLIST
LF_DEAD_PATH=(); LF_DEAD_OWNER=(); LF_DEAD_INFO=()
LF_REVIEW_PATH=(); LF_REVIEW_OWNER=(); LF_REVIEW_INFO=()
LF_KEPT=0
lf_scan "$AG" "$SBX/home"
if [ "${#LF_DEAD_PATH[@]}" -eq 1 ] && [ "${#LF_REVIEW_PATH[@]}" -eq 1 ] && [ "$LF_KEPT" -eq 3 ] \
   && [ "${LF_DEAD_PATH[0]}" = "$AG/com.test.dead.plist" ] \
   && [ "${LF_DEAD_OWNER[0]}" = "$SBX/home" ] \
   && [ "${LF_DEAD_INFO[0]}" = "$SBX/gone/nope-binary" ] \
   && [ "${LF_REVIEW_PATH[0]}" = "$AG/com.test.review.plist" ] \
   && [ "${LF_REVIEW_OWNER[0]}" = "$SBX/home" ] \
   && printf '%s' "${LF_REVIEW_INFO[0]}" | grep -q 'Definitely Gone 9000.app'; then
  pass "lf_scan: dead / likely-orphan / kept classified correctly (live + apple never flagged)"
else
  fail "lf_scan misclassified (dead=${#LF_DEAD_PATH[@]} review=${#LF_REVIEW_PATH[@]} kept=$LF_KEPT)"
fi
teardown

# (M1) Multi-account routing: an item from account A must land in A's OWN Trash,
# and B's in B's — never crossed. This is the multi-account guarantee that can't
# be exercised with one real login, proven here at the routing level.
setup
A="$SBX/acctA"; B="$SBX/acctB"; mkdir -p "$A" "$B" "$SBX/src"
echo a > "$SBX/src/itemA"; echo b > "$SBX/src/itemB"
to_trash "$SBX/src/itemA" "$A"; da="$TRASH_DEST"
to_trash "$SBX/src/itemB" "$B"; db="$TRASH_DEST"
if [ -f "$A/.Trash/itemA" ] && [ -f "$B/.Trash/itemB" ] \
   && [ ! -e "$B/.Trash/itemA" ] && [ ! -e "$A/.Trash/itemB" ] \
   && [ "$da" = "$A/.Trash/itemA" ] && [ "$db" = "$B/.Trash/itemB" ]; then
  pass "to_trash routes each item to its OWNER account's Trash (multi-account)"
else
  fail "to_trash crossed accounts (da=$da db=$db)"
fi
teardown

# (L2) restore must undo a LEFTOVERS sweep too: a leftovers receipt (app=leftovers)
# moves an orphaned plist back from the Trash to where it lived. Proves the two
# verbs share one undo.
setup
REAL_HOME="$SBX/home"
mkdir -p "$REAL_HOME/.sheersweep/uninstalls" "$REAL_HOME/.Trash"
echo plist > "$REAL_HOME/.Trash/com.ea.origin.ESHelper.plist"
orig="$SBX/Library/LaunchDaemons/com.ea.origin.ESHelper.plist"
rfile="$REAL_HOME/.sheersweep/uninstalls/20260616-000010-leftovers.tsv"
{ echo "# sheersweep leftovers receipt"; echo "# app=leftovers"; echo "# bid=leftovers"
  echo "# date=20260616-000010"; echo "# format=nul-pairs"; printf '\0'
  printf '%s\0%s\0' "$REAL_HOME/.Trash/com.ea.origin.ESHelper.plist" "$orig"; } > "$rfile"
printf 'y\n' | do_restore >/dev/null 2>&1
if [ -f "$orig" ] && [ "$(cat "$orig")" = "plist" ] && [ -f "$rfile.restored" ]; then
  pass "restore undoes a leftovers sweep (leftovers receipt round-trips)"
else
  fail "restore failed to undo a leftovers sweep (orig exists: $([ -f "$orig" ] && echo y || echo n))"
fi
teardown

# (C1) the sweep's clean(): a real run empties a dir's CONTENTS but KEEPS the dir;
# --dry-run reports and deletes nothing. This is the only delete path in the sweep.
setup
mkdir -p "$SBX/cache/sub"
dd if=/dev/zero of="$SBX/cache/blob" bs=1024 count=8 2>/dev/null
echo x > "$SBX/cache/sub/f"
DRY=0
clean "$SBX/cache" >/dev/null 2>&1
real_ok=0
{ [ -d "$SBX/cache" ] && [ -z "$(find "$SBX/cache" -mindepth 1 2>/dev/null)" ]; } && real_ok=1
mkdir -p "$SBX/cache2"; echo keep > "$SBX/cache2/file"
DRY=1
clean "$SBX/cache2" >/dev/null 2>&1
# shellcheck disable=SC2034  # DRY is read inside the sourced clean(), not in this file
DRY=0
dry_ok=0
[ -f "$SBX/cache2/file" ] && dry_ok=1
if [ "$real_ok" -eq 1 ] && [ "$dry_ok" -eq 1 ]; then
  pass "clean(): real run empties the dir but keeps it; --dry-run deletes nothing"
else
  fail "clean() wrong (real_ok=$real_ok dry_ok=$dry_ok)"
fi
teardown

# (i18n) locale resolution: every supported locale maps through (including both
# Chinese scripts — Traditional stays zh-TW, Simplified now gets zh-Hans instead
# of the old English fallback), and an unsupported locale falls back to en-US.
loc_ok=1
chk() {   # $1 = input locale  $2 = expected resolution
  local got; got="$(SHEERSWEEP_LANG=$1 ss_resolve_lang)"
  [ "$got" = "$2" ] || { loc_ok=0; echo "     $1 → $got (want $2)"; }
}
chk ja_JP ja-JP
chk zh_TW zh-TW;  chk zh-Hant zh-TW;  chk zh_HK zh-TW
chk zh_CN zh-Hans; chk zh-Hans zh-Hans; chk zh_SG zh-Hans
chk ko_KR ko-KR
chk es_ES es-ES;  chk es_MX es-ES
chk de_DE de-DE;  chk de_AT de-DE
chk fr_FR fr-FR;  chk fr_CA fr-FR
chk pt_BR pt-BR;  chk pt_PT pt-BR
chk it_IT en-US;  chk "" en-US
if [ "$loc_ok" -eq 1 ]; then
  pass "locale: all 9 locales resolve (zh_CN → zh-Hans); unsupported falls back to en-US"
else
  fail "locale resolution wrong"
fi

# (catalog) Vendor-nested data catalog: Chrome resolves to its PRODUCT subfolders
# (Application Support/Google/Chrome), name<->bid round-trips, and an unknown bid
# yields nothing — the guarantee that `uninstall` now reaches profile data the
# standard patterns miss, without ever guessing.
chrome_extra="$(catalog_extra_rel com.google.Chrome | tr '\n' '|')"
unknown_extra="$(catalog_extra_rel com.no.such.app)"
n2b="$(catalog_bid_for_name "Google Chrome")"
b2n="$(catalog_name_for_bid com.brave.Browser)"
if [ "$chrome_extra" = "Application Support/Google/Chrome|Caches/Google/Chrome|" ] \
   && [ -z "$unknown_extra" ] \
   && [ "$n2b" = "com.google.Chrome" ] && [ "$b2n" = "Brave Browser" ]; then
  pass "catalog: Chrome → product subfolders; name<->bid round-trip; unknown → empty"
else
  fail "catalog wrong (chrome=[$chrome_extra] unknown=[$unknown_extra] n2b=$n2b b2n=$b2n)"
fi

# (guard) extra_is_safe is the belt-and-suspenders that protects a sibling app:
# a PRODUCT subfolder is removable, but a shared VENDOR ROOT (Application Support/
# Google — which also holds Google Drive's DriveFS) must be refused even if a
# future catalog typo lists it. This is the test that keeps DriveFS safe.
guard_ok=1
extra_is_safe "Application Support/Google/Chrome" || guard_ok=0          # product → safe
extra_is_safe "Application Support/BraveSoftware/Brave-Browser" || guard_ok=0
extra_is_safe "Application Support/Google" && guard_ok=0                 # vendor root → refuse
extra_is_safe "Caches/Google" && guard_ok=0
extra_is_safe "Application Support/BraveSoftware" && guard_ok=0
if [ "$guard_ok" -eq 1 ]; then
  pass "guard: product subfolders pass; shared vendor roots (Google/, BraveSoftware/) refused"
else
  fail "extra_is_safe guard wrong — a vendor root was not refused (DriveFS at risk)"
fi

# (security) to_trash must REFUSE a .Trash that is a symlink — otherwise a hostile
# account could point its own ~/.Trash at a system dir and make our root-run mv
# write THROUGH the link outside their home. The item must stay put, TRASH_DEST empty.
setup
HOME_OWNER="$SBX/home"; mkdir -p "$HOME_OWNER" "$SBX/evil-target"
ln -s "$SBX/evil-target" "$HOME_OWNER/.Trash"        # .Trash → attacker-chosen dir
echo x > "$SBX/item"
to_trash "$SBX/item" "$HOME_OWNER"
if [ -z "$TRASH_DEST" ] && [ ! -e "$SBX/evil-target/item" ] && [ -e "$SBX/item" ]; then
  pass "to_trash refuses a symlinked .Trash (no write through the link)"
else
  fail "to_trash followed a symlinked .Trash → wrote to $TRASH_DEST"
fi
teardown

# (security) vis() must strip terminal control bytes from untrusted display
# strings — a cross-account filename can embed ESC/CSI to forge the consent screen.
setup
raw="$(printf 'evil\033[2Kforged\ttab\r')"           # ESC + CSI + TAB + CR
got="$(printf '%s' "$raw" | vis)"
if printf '%s' "$got" | LC_ALL=C grep -q '[[:cntrl:]]'; then
  fail "vis left a control byte in the output"
else
  pass "vis strips ESC/control bytes from untrusted display strings"
fi
teardown

# (guard) unmanaged_bins must list only what has NO other uninstaller: a plain
# executable is a candidate, but a symlink into a Homebrew keg or an .app bundle
# is owned by brew / the app — trashing it would half-uninstall someone else's
# install. Uses an exact-name query so real /usr/local/bin contents can't leak in.
setup
FAKE_HOME="$SBX/home"
mkdir -p "$FAKE_HOME/bin" "$FAKE_HOME/.local/bin" "$SBX/Cellar/tool-a/1.0/bin" "$SBX/Fake.app/Contents/MacOS"
uniq="ss-func-test-bin-$$"
printf '#!/bin/sh\n' > "$FAKE_HOME/bin/$uniq"; chmod +x "$FAKE_HOME/bin/$uniq"
printf '#!/bin/sh\n' > "$SBX/Cellar/tool-a/1.0/bin/tool-a"; chmod +x "$SBX/Cellar/tool-a/1.0/bin/tool-a"
printf '#!/bin/sh\n' > "$SBX/Fake.app/Contents/MacOS/tool-b"; chmod +x "$SBX/Fake.app/Contents/MacOS/tool-b"
ln -s "$SBX/Cellar/tool-a/1.0/bin/tool-a" "$FAKE_HOME/.local/bin/tool-a"
ln -s "$SBX/Fake.app/Contents/MacOS/tool-b" "$FAKE_HOME/.local/bin/tool-b"
got_plain=""; while IFS= read -r -d '' f; do got_plain="$f"; done < <(unmanaged_bins "$uniq" "$FAKE_HOME")
got_keg="";   while IFS= read -r -d '' f; do got_keg="$f";   done < <(unmanaged_bins "tool-a" "$FAKE_HOME")
got_app="";   while IFS= read -r -d '' f; do got_app="$f";   done < <(unmanaged_bins "tool-b" "$FAKE_HOME")
if [ "$got_plain" = "$FAKE_HOME/bin/$uniq" ] && [ -z "$got_keg" ] && [ -z "$got_app" ]; then
  pass "unmanaged_bins: plain binary listed; Homebrew-keg and .app symlinks skipped"
else
  fail "unmanaged_bins wrong (plain=[$got_plain] keg=[$got_keg] app=[$got_app])"
fi
teardown

# (guard) looks_like_bid gates what can EVER become an orphan candidate: only
# the bundle-id shape passes, so a vendor-NAME folder (Adobe, Code) — the thing
# we can't prove — can't even enter the pipeline.
lb_ok=1
for good in com.foo.bar org.x-y.z com.a.b.c.d zoom.us; do
  looks_like_bid "$good" || { lb_ok=0; echo "     rejected good: $good"; }
done
for bad in Adobe Code ".hidden" "foo." "zoom us" "foo/bar" "com..~" "a b.c" \
           group.com.apple.mail systemgroup.com.apple.icloud \
           EQHXZ8M8AV.group.com.google.drivefs 243LU875E5.groups.com.apple.podcasts; do
  looks_like_bid "$bad" && { lb_ok=0; echo "     accepted bad: $bad"; }
done
if [ "$lb_ok" -eq 1 ]; then
  pass "looks_like_bid: id shapes pass; names/paths/edges + the group namespace (group./systemgroup./team-id) refused"
else
  fail "looks_like_bid misclassified (see above)"
fi

# (P1 guard) the claim scan must cover every way a LIVE app owns id-named data —
# this is what keeps discovery from offering a living app's files as "orphans":
#   • exact top-level id            • dot-prefix child (Chrome-helper style)
#   • dot-prefix parent             • NESTED Info.plist with a DIVERGENT id
#     (Teams-launcher style — no prefix relation to the app's own id)
#   • the app's folder NAME (zoom.us.app names its data "zoom.us")
#   • com.apple.* never surfaces at all
# Only the genuinely unclaimed id may survive the filter.
setup
plist() {   # $1=path $2=bundle id
  mkdir -p "$(dirname "$1")"
  printf '<?xml version="1.0" encoding="UTF-8"?>\n<plist version="1.0"><dict><key>CFBundleIdentifier</key><string>%s</string></dict></plist>\n' "$2" > "$1"
}
APPS="$SBX/Apps"
plist "$APPS/Live.app/Contents/Info.plist" "com.vendor.live"
plist "$APPS/Live.app/Contents/Library/LoginItems/Launcher.app/Contents/Info.plist" "com.divergent.launcher"
plist "$APPS/zoom.us.app/Contents/Info.plist" "us.zoom.xos"
# vendors nest apps deep (CLIP STUDIO PAINT is 3 levels down, its helpers 4) —
# the claim scan must be full-depth or a LIVE deep app reads as an orphan
plist "$APPS/Suite 1.5/App/Deep.app/Contents/Info.plist" "com.suite.deep"
collect_claims "$APPS"
survivors="$(printf '%s\n' \
  com.vendor.live com.vendor.live.helper com.vendor \
  com.divergent.launcher zoom.us com.apple.anything \
  com.suite.deep com.suite.deep.LipPreview com.gone.app \
  | filter_unclaimed)"
if [ "$survivors" = "com.gone.app" ]; then
  pass "claims: exact/prefix-both-ways/nested-divergent/name/apple/deep-nested all kept; only true orphan survives"
else
  fail "claim filter wrong (survivors=[$survivors], want only com.gone.app)"
fi
teardown

# (e2e) orphan_discover on a fixture home: a strong-family orphan surfaces even
# when tiny; a big weak one surfaces by size; a tiny lone plist folds into
# OD_SMALL; claimed and vendor-NAME data never appear. Largest first.
setup
plist "$SBX/Apps/Live.app/Contents/Info.plist" "com.vendor.live"
H="$SBX/home"; L="$H/Library"
mkdir -p "$L/Containers/com.gone.app" "$L/Application Support/Adobe" \
         "$L/Application Support/com.vendor.live" "$L/Preferences" \
         "$L/Group Containers/group.is.workflow.my.app" \
         "$L/Application Scripts/group.is.workflow.my.app" \
         "$L/Application Scripts/EQHXZ8M8AV.group.com.live.drive" \
         "$L/Application Scripts/systemgroup.com.apple.thing" \
         "$L/Group Containers/EQHXZ8M8AV.group.com.live.drive"
echo data > "$L/Containers/com.gone.app/state"
dd if=/dev/zero of="$L/Preferences/com.big.tool.plist" bs=1024 count=1500 2>/dev/null
echo tiny > "$L/Preferences/com.tiny.left.plist"
# a loose id-ish FILE in the Application Support root (SwiftData's default
# store) names a file format, not an app — it must never become a candidate
echo sqlite > "$L/Application Support/default.store"
collect_claims "$SBX/Apps"
orphan_discover "$H"
od_list="$(printf '%s ' "${OD_IDS[@]-}")"
if [ "${#OD_IDS[@]}" -eq 2 ] && [ "${OD_IDS[0]}" = "com.big.tool" ] \
   && [ "${OD_IDS[1]}" = "com.gone.app" ] \
   && [ "${#OD_TIDS[@]}" -eq 1 ] && [ "${OD_TIDS[0]}" = "com.tiny.left" ]; then
  pass "orphan_discover: strong+big surfaced (largest first), tiny listed in the tail; claimed/name-dirs/AS-files/group.* never appear"
else
  fail "orphan_discover wrong (ids=[$od_list] tail=[${OD_TIDS[*]-}])"
fi
# …but a PROVEN orphan's group container still rides along with its footprint
mkdir -p "$L/Group Containers/group.com.gone.app"
gc_seen=0
while IFS= read -r -d '' p; do
  [ "$p" = "$L/Group Containers/group.com.gone.app" ] && gc_seen=1
done < <(orphan_paths_home "com.gone.app" "$H")
if [ "$gc_seen" -eq 1 ]; then
  pass "group container can't nominate, but a proven orphan's group data rides along"
else
  fail "proven orphan's group container missing from its footprint"
fi
# the hint is derived, generic last components step back one, and it's lowercase
h1="$(orphan_hint com.spotify.client)"; h2="$(orphan_hint com.gone.app)"
h3="$(orphan_hint org.MacVim)"; h4="$(orphan_hint calibre-ebook.com)"
if [ "$h1" = "spotify" ] && [ "$h2" = "gone" ] && [ "$h3" = "macvim" ] && [ "$h4" = "calibre-ebook" ]; then
  pass "orphan_hint: generic tail steps back (client/app/TLD), lowercased"
else
  fail "orphan_hint wrong ($h1/$h2/$h3/$h4)"
fi
teardown

# (guard) pick_parse: the multi-select grammar. A multi selection may MIX app
# and orphan rows (batch selection, serial consent — apps still confirm one at
# a time downstream); ranges expand, dupes collapse, `all` covers every orphan
# row and NEVER an app row ("all" must not be able to mean "uninstall every
# installed app"), and anything malformed or out of range is rejected as a
# whole — never a partial pick.
pp_ok=1
pp() {   # $1=input $2=napps $3=total $4=expected rows ("-" = expect invalid)
  local got="-"
  if pick_parse "$1" "$2" "$3"; then got="${PICK_ROWS[*]}"; fi
  [ "$got" = "$4" ] || { pp_ok=0; echo "     pick_parse '$1' → [$got], want [$4]"; }
}
pp "19"          18 30 "19"            # single orphan row
pp "5"           18 30 "5"             # single app row is fine alone
pp "19 20,25-27" 18 30 "19 20 25 26 27"  # spaces+commas+range
pp "19 19 19"    18 30 "19"            # dupes collapse
pp "all"         18 21 "19 20 21"      # all = every orphan row
pp "5 19"        18 30 "5 19"          # apps MAY mix into a multi pick (v0.9.1)
pp "19-20 5 7 8" 18 30 "19 20 5 7 8"   # the field report that unlocked this, verbatim
pp "18-20"       18 30 "18 19 20"      # range may cross the app/orphan border
pp "31"          18 30 "-"             # out of range
pp "20-19"       18 30 "-"             # backwards range
pp "19 x"        18 30 "-"             # junk token poisons the whole pick
pp "all"         18 18 "-"             # no orphans → no all
pp "all"         18 30 "19 20 21 22 23 24 25 26 27 28 29 30"  # all NEVER includes app rows
if [ "$pp_ok" -eq 1 ]; then
  pass "pick_parse: ranges/dupes/all ok; multi mixes apps+orphans; all is 🧟-only; junk rejects whole"
else
  fail "pick_parse misparsed (see above)"
fi

# (P1 guard) honest move accounting: three real runs "succeeded" (✅) while
# every macOS-protected container silently stayed put. trash_one must count
# tried vs moved, mark a stuck item ❌ out loud, flag the container case, and
# report_moves must turn any shortfall into a 🔴 with real numbers — plus the
# actionable 🔒 hint when containers are what stuck.
setup
HOME_OWNER="$SBX/home"; mkdir -p "$HOME_OWNER"
mkdir -p "$SBX/fake/Library/Containers/com.stuck.app"; echo x > "$SBX/fake/Library/Containers/com.stuck.app/f"
mkdir -p "$SBX/loose"; echo y > "$SBX/loose/plain.plist"
ln -s "$SBX/elsewhere" "$HOME_OWNER/.Trash"          # symlinked Trash → to_trash refuses silently
RF="$SBX/r.tsv"; : > "$RF"
# NOTE: redirection, not $( ) — command substitution would subshell trash_one
# and the MV_* accounting (dynamic scope) would never reach report_moves.
# shellcheck disable=SC2034  # consumed inside the sourced trash_one/report_moves
MV_TRIED=0; MV_MOVED=0; MV_STUCK_CONT=0
trash_one "$SBX/fake/Library/Containers/com.stuck.app" "$HOME_OWNER" "$RF" > "$SBX/out1"
report_moves "SHOULD-NOT-PRINT" > "$SBX/sum1"
out1="$(cat "$SBX/out1")"; sum1="$(cat "$SBX/sum1")"
rm "$HOME_OWNER/.Trash"                               # heal the Trash → moves succeed again
# shellcheck disable=SC2034  # consumed inside the sourced trash_one/report_moves
MV_TRIED=0; MV_MOVED=0; MV_STUCK_CONT=0
trash_one "$SBX/loose/plain.plist" "$HOME_OWNER" "$RF" > "$SBX/out2"
report_moves "ALL-GOOD-LINE" > "$SBX/sum2"
out2="$(cat "$SBX/out2")"; sum2="$(cat "$SBX/sum2")"
: "reads for shellcheck — the real consumers live in the sourced script: $MV_TRIED $MV_MOVED $MV_STUCK_CONT"
case "$out1" in *"❌"*) ok1=1 ;; *) ok1=0 ;; esac
case "$sum1" in *"🔴"*"0"*"1"*|*"🔴"*) ok2=1 ;; *) ok2=0 ;; esac
case "$sum1" in *"🔒"*) ok3=1 ;; *) ok3=0 ;; esac
case "$out2" in *"❌"*) ok4=0 ;; *) ok4=1 ;; esac
[ "$sum2" = "ALL-GOOD-LINE" ] && ok5=1 || ok5=0
if [ "$ok1$ok2$ok3$ok4$ok5" = "11111" ]; then
  pass "honest accounting: stuck item ❌ + 🔴 shortfall + 🔒 container hint; full success keeps plain ✅"
else
  fail "move accounting wrong (stuck-mark=$ok1 shortfall=$ok2 hint=$ok3 clean-item=$ok4 clean-summary=$ok5)"
fi
teardown

# (regression) Adobe has LEFT the sweep entirely — no vendor name in the sweep's
# clean list, no installed-check machinery, no help-text carve-out. The residue
# story now lives in uninstall's discovery, where it belongs.
if ! grep -q 'Application Support/Adobe' "$SCRIPT" \
   && ! grep -q 'Caches/Adobe' "$SCRIPT" \
   && ! grep -q 'adobe_installed' "$SCRIPT"; then
  pass "sweep names no vendor: Application Support/Adobe + guard are gone"
else
  fail "Adobe still referenced by the sweep/help"
fi

# (P1 guard) reclaim's three gates — the conjunction is the safety story:
# gitignored AND known pattern AND sibling manifest. Each gate alone must NOT
# be enough, and an Obsidian vault is invisible even when all three hold.
setup
export SHEERSWEEP_LANG=en-US
R="$SBX/roots"; REAL_HOME="$SBX/home"; mkdir -p "$REAL_HOME"
mkrepo() {   # $1=dir — a git repo with one committed file
  mkdir -p "$1"; git -C "$1" init -q
  echo x > "$1/src.txt"; printf 'node_modules\ndist\ntarget\n.build\n' > "$1/.gitignore"
  git -C "$1" -c user.email=t@t -c user.name=t add -A
  git -C "$1" -c user.email=t@t -c user.name=t commit -qm init
}
# ① eligible: ignored + pattern + manifest
mkrepo "$R/good"; echo '{}' > "$R/good/package.json"
mkdir -p "$R/good/node_modules/dep"; echo j > "$R/good/node_modules/dep/i.js"
# ② no manifest: a content folder literally named dist
mkrepo "$R/nomanifest"; mkdir -p "$R/nomanifest/dist"; echo data > "$R/nomanifest/dist/mine.txt"
# ③ not gitignored: pattern + manifest but git tracks it
mkrepo "$R/tracked"; echo '{}' > "$R/tracked/package.json"
mkdir -p "$R/tracked/node_modules"; echo j > "$R/tracked/node_modules/i.js"
: > "$R/tracked/.gitignore"   # nothing ignored here
# ④ no git repo at all
mkdir -p "$R/norepo/node_modules"; echo '{}' > "$R/norepo/package.json"; echo j > "$R/norepo/node_modules/i.js"
# ⑤ a vault: all three gates hold, but an ancestor carries .obsidian
mkrepo "$R/vault"; mkdir -p "$R/vault/.obsidian"; echo '{}' > "$R/vault/package.json"
mkdir -p "$R/vault/node_modules"; echo j > "$R/vault/node_modules/i.js"
DRY=1; RC_ROOTS=("$R"); RC_STALE_DAYS=""
: "reads for shellcheck — consumed in the sourced do_reclaim: $DRY ${RC_ROOTS[*]} $RC_STALE_DAYS"
out="$(do_reclaim 2>&1)"
ok1=0; case "$out" in *"good/node_modules"*|*"node_modules"*) ok1=1 ;; esac
ok2=1; case "$out" in *nomanifest*) ok2=0 ;; esac
ok3=1; case "$out" in *tracked*) ok3=0 ;; esac
ok4=1; case "$out" in *norepo*) ok4=0 ;; esac
ok5=1; case "$out" in *vault*) ok5=0 ;; esac
if [ "$ok1$ok2$ok3$ok4$ok5" = "11111" ]; then
  pass "reclaim gates: eligible found; no-manifest / tracked / repo-less / vault all invisible"
else
  fail "reclaim gates wrong (found=$ok1 nomanifest=$ok2 tracked=$ok3 norepo=$ok4 vault=$ok5)"
fi

# (guard) --stale honours max(commit, tracked mtime): an old repo passes the
# filter; the same repo with ONE freshly-touched tracked file does not.
old="202601010000"
git -C "$R/good" -c user.email=t@t -c user.name=t commit -q --amend --no-edit --date="2026-01-01T00:00:00"
GIT_COMMITTER_DATE="2026-01-01T00:00:00" git -C "$R/good" -c user.email=t@t -c user.name=t commit -q --amend --no-edit --date="2026-01-01T00:00:00"
touch -t "$old" "$R/good/src.txt" "$R/good/.gitignore" "$R/good/package.json"
RC_STALE_DAYS=30; : "$RC_STALE_DAYS"
out="$(do_reclaim 2>&1)"
case "$out" in *node_modules*) s1=1 ;; *) s1=0 ;; esac
touch "$R/good/src.txt"                       # tracked file edited just now
out="$(do_reclaim 2>&1)"
case "$out" in *node_modules*) s2=0 ;; *) s2=1 ;; esac
RC_STALE_DAYS=""; : "$RC_STALE_DAYS"
if [ "$s1$s2" = "11" ]; then
  pass "reclaim --stale: old repo passes; one fresh tracked edit shields it"
else
  fail "reclaim --stale wrong (old-in=$s1 fresh-out=$s2)"
fi

# (guard) the rebuild command follows the lockfile
r1="$(rc_rebuild_for node_modules "$R/good")"
touch "$R/good/pnpm-lock.yaml"; r2="$(rc_rebuild_for node_modules "$R/good")"
rm "$R/good/pnpm-lock.yaml"; touch "$R/good/yarn.lock"; r3="$(rc_rebuild_for dist "$R/good")"
r4="$(rc_rebuild_for .build "$R/good")"; r5="$(rc_rebuild_for target "$R/good")"
if [ "$r1" = "npm install" ] && [ "$r2" = "pnpm install" ] && [ "$r3" = "yarn run build" ] \
   && [ "$r4" = "swift build" ] && [ "$r5" = "cargo build" ]; then
  pass "reclaim rebuild map: lockfile picks the package manager; swift/cargo mapped"
else
  fail "rebuild map wrong ($r1 / $r2 / $r3 / $r4 / $r5)"
fi
rm -f "$R/good/yarn.lock"

# (e2e) real reclaim run: select all → typed count → Trash under the fixture
# home → receipt carries kind=reclaim and the rebuild command → restore preview
# surfaces the rebuild hint.
DRY=0; : "$DRY"
do_reclaim <<< $'all\n1' > "$SBX/rc.out" 2>&1
RC_RECEIPT="$(find "$REAL_HOME/.sheersweep/uninstalls" -name "*-reclaim.tsv" 2>/dev/null | head -1)"
e1=0; [ ! -e "$R/good/node_modules" ] && e1=1
e2=0; [ -n "$RC_RECEIPT" ] && [ "$(receipt_header "$RC_RECEIPT" kind)" = "reclaim" ] && e2=1
e3=0; receipt_header_all "$RC_RECEIPT" rebuild 2>/dev/null | grep -q "npm install" && e3=1
e4=0; grep -q "✅" "$SBX/rc.out" && e4=1
if [ "$e1$e2$e3$e4" = "1111" ]; then
  pass "reclaim e2e: moved to Trash, receipt kind=reclaim with rebuild command, honest ✅"
else
  fail "reclaim e2e wrong (moved=$e1 kind=$e2 rebuild=$e3 done=$e4) $(tail -3 "$SBX/rc.out")"
fi
teardown

# (unidentified tier) a heavy, gitignored, off-list, no-manifest folder is
# SURFACED in the separate 🔺 section; a proven dir is NOT double-listed there;
# a below-floor dir and — critically — a heavy NOT-gitignored folder (possible
# unsaved work) are never shown. The last is the safety line: the tier only ever
# offers what the owner already told git to ignore.
setup
export SHEERSWEEP_LANG=en-US
R="$SBX/roots"; REAL_HOME="$SBX/home"; mkdir -p "$REAL_HOME"
mkdir -p "$R/proj"; git -C "$R/proj" init -q
echo x > "$R/proj/src.txt"
printf '.harvest/\nnode_modules/\ntiny/\n' > "$R/proj/.gitignore"
git -C "$R/proj" -c user.email=t@t -c user.name=t add -A
git -C "$R/proj" -c user.email=t@t -c user.name=t commit -qm init
mkdir -p "$R/proj/.harvest";       dd if=/dev/zero of="$R/proj/.harvest/blob" bs=1024 count=200 2>/dev/null   # ~200K off-list no-manifest
echo '{}' > "$R/proj/package.json"
mkdir -p "$R/proj/node_modules/d"; dd if=/dev/zero of="$R/proj/node_modules/d/x" bs=1024 count=200 2>/dev/null # proven (pattern+manifest)
mkdir -p "$R/proj/tiny"; echo z > "$R/proj/tiny/z"                                                            # below the floor
mkdir -p "$R/proj/work";           dd if=/dev/zero of="$R/proj/work/big" bs=1024 count=200 2>/dev/null         # heavy but NOT gitignored
RC_UNID_MIN_KB=64
DRY=1; RC_ROOTS=("$R"); RC_STALE_DAYS=""
: "reads for shellcheck — consumed in the sourced do_reclaim: $DRY ${RC_ROOTS[*]} $RC_STALE_DAYS $RC_UNID_MIN_KB"
out="$(do_reclaim 2>&1)"
unid_lines="$(printf '%s\n' "$out" | grep '🔺' || true)"
u1=0; printf '%s\n' "$unid_lines" | grep -q '\.harvest'    && u1=1   # surfaced as unidentified
u2=1; printf '%s\n' "$unid_lines" | grep -q 'node_modules' && u2=0   # proven → not double-listed here
u3=1; case "$out" in *"proj/tiny"*) u3=0 ;; esac                     # below floor → hidden
u4=1; case "$out" in *"proj/work"*) u4=0 ;; esac                     # not gitignored → hidden (unsaved-work safety)
RC_UNID_MIN_KB=$(( 512 * 1024 ))
if [ "$u1$u2$u3$u4" = "1111" ]; then
  pass "reclaim unidentified: heavy off-list gitignored surfaced; proven not double-listed; below-floor & non-ignored hidden"
else
  fail "reclaim unidentified wrong (harvest=$u1 dedup=$u2 tiny=$u3 work=$u4)"
fi
teardown

# (unified pick) proven and unidentified share ONE numbered list. Picking a 🔺
# row by its number, then confirming by TYPING ITS NAME, moves only that folder —
# the proven rows (not picked) stay put. This is the uninstall model: number to
# select, type-name to confirm.
setup
export SHEERSWEEP_LANG=en-US
R="$SBX/roots"; REAL_HOME="$SBX/home"; mkdir -p "$REAL_HOME"
mkdir -p "$R/proj"; git -C "$R/proj" init -q
echo x > "$R/proj/src.txt"
printf 'node_modules/\ncrawl/\n' > "$R/proj/.gitignore"
git -C "$R/proj" -c user.email=t@t -c user.name=t add -A
git -C "$R/proj" -c user.email=t@t -c user.name=t commit -qm init
echo '{}' > "$R/proj/package.json"
mkdir -p "$R/proj/node_modules/d"; dd if=/dev/zero of="$R/proj/node_modules/d/x" bs=1024 count=200 2>/dev/null # proven → row 1
mkdir -p "$R/proj/crawl";          dd if=/dev/zero of="$R/proj/crawl/blob"      bs=1024 count=200 2>/dev/null # unidentified → row 2
RC_UNID_MIN_KB=64; DRY=0; RC_ROOTS=("$R"); RC_STALE_DAYS=""
: "reads for shellcheck: $RC_UNID_MIN_KB $DRY ${RC_ROOTS[*]} $RC_STALE_DAYS"
do_reclaim <<< $'2\ncrawl' > "$SBX/u.out" 2>&1     # pick the 🔺 row (2), confirm by name
RC_UNID_MIN_KB=$(( 512 * 1024 ))
p1=0; [ ! -e "$R/proj/crawl" ] && p1=1                                                # picked 🔺 moved
p2=0; [ -e "$R/proj/node_modules" ] && p2=1                                           # unpicked proven kept
p3=0; find "$REAL_HOME/.Trash" -name crawl 2>/dev/null | grep -q . && p3=1            # landed in Trash
if [ "$p1$p2$p3" = "111" ]; then
  pass "reclaim unified pick: a 🔺 row picked by number + typed name moves only it; proven untouched"
else
  fail "reclaim unified pick wrong (crawl_gone=$p1 nm_kept=$p2 trashed=$p3) $(tail -3 "$SBX/u.out")"
fi
teardown

# (guard) the sweep digest is REPORT-only formatting over finder results: each
# fabricated result renders its localized line, sub-threshold AI size and
# zero-count finders contribute nothing, and an empty digest prints NOTHING.
setup
DG_DIR="$SBX/dg"; mkdir -p "$DG_DIR"
printf '3 1048576\n' > "$DG_DIR/orph"     # 3 orphans · 1.0G
printf '2 2097152\n' > "$DG_DIR/rc"       # 2 folders · 2.0G
printf '4\n'         > "$DG_DIR/brew"     # 4 outdated
printf '204800\n'    > "$DG_DIR/ai"       # 200M ≥ threshold
true & DG_PID=$!; wait "$DG_PID" 2>/dev/null   # a finished pid → zero grace wait
out="$(dg_print)"
g1=0; case "$out" in *"🧟"*1.0G*"(3)"*) g1=1 ;; esac
g2=0; case "$out" in *"♻️"*2.0G*) g2=1 ;; esac
g3=0; case "$out" in *"↑"*4*) g3=1 ;; esac
g4=0; case "$out" in *"🤖"*200M*) g4=1 ;; esac
DG_DIR="$SBX/dg2"; mkdir -p "$DG_DIR"
printf '0 0\n' > "$DG_DIR/orph"; printf '10240\n' > "$DG_DIR/ai"   # zero + sub-100M
true & DG_PID=$!; wait "$DG_PID" 2>/dev/null
out2="$(dg_print)"
g5=0; [ -z "$out2" ] && g5=1
if [ "$g1$g2$g3$g4$g5" = "11111" ]; then
  pass "digest: four lines render localized; zero/sub-threshold finders silent; empty digest prints nothing"
else
  fail "digest wrong (orph=$g1 rc=$g2 brew=$g3 ai=$g4 empty=$g5) out=[$out] out2=[$out2]"
fi
# dg_ai_kb: named session dirs only, homes passed explicitly
mkdir -p "$SBX/h1/.claude/projects" "$SBX/h1/.clikae/profiles/claude/l/projects"
dd if=/dev/zero of="$SBX/h1/.claude/projects/s.jsonl" bs=1024 count=64 2>/dev/null
kb="$(dg_ai_kb "$SBX/h1")"; kb0="$(dg_ai_kb "$SBX/empty-home")"
if [ "${kb:-0}" -ge 64 ] && [ "${kb0:-x}" = "0" ]; then
  pass "dg_ai_kb: measures named session dirs; empty home → 0"
else
  fail "dg_ai_kb wrong (kb=$kb kb0=$kb0)"
fi
teardown

# (guard) EVERY t() key must exist in EVERY supported locale — the key list is
# extracted from the script itself so a future key can't dodge the check. The
# i18n rule is tiered (command lines stay raw) but a key that IS localized may
# never silently fall back for one language, least of all a consent prompt.
i18n_ok=1
all_keys="$(awk '/^t\(\) \{/,/^\}/' "$SCRIPT" | grep -oE '^    [a-z][a-z_0-9]*\)' | tr -d ' )')"
n_keys="$(printf '%s\n' "$all_keys" | grep -c .)"
# the locale list is extracted from ss_resolve_lang too — a PR that adds a
# language is enforced automatically, without touching this test.
all_locs="$(awk '/^ss_resolve_lang\(\) \{/,/^\}/' "$SCRIPT" | grep -oE 'echo "[A-Za-z-]+"' | sed 's/echo //; s/"//g' | sort -u)"
n_locs="$(printf '%s\n' "$all_locs" | grep -c .)"
for key in $all_keys; do
  for loc in $all_locs; do
    SS_LANG="$loc"   # read by the sourced t()
    [ -n "$(t "$key")" ] || { i18n_ok=0; echo "     missing: $key ($loc)"; }
  done
done
# shellcheck disable=SC2034  # read by the sourced library, not this file
SS_LANG="en-US"
if [ "$i18n_ok" -eq 1 ] && [ "$n_keys" -ge 70 ] && [ "$n_locs" -ge 9 ]; then
  pass "i18n: all $n_keys t() keys present in all $n_locs locales"
else
  fail "i18n: a key is missing a locale (or extraction broke: $n_keys keys / $n_locs locales)"
fi

echo "→ func-test done"
[ "$fails" -eq 0 ] || { echo "❌ $fails functional test(s) failed"; exit 1; }
echo "✅ func-test all green"
