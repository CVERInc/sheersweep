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
