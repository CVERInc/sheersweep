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

echo "→ func-test done"
[ "$fails" -eq 0 ] || { echo "❌ $fails functional test(s) failed"; exit 1; }
echo "✅ func-test all green"
