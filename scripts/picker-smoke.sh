#!/usr/bin/env bash
# picker-smoke — run the picker's REAL path once, before a release.
#
# Why this exists, and why it is not in scripts/func-test.sh:
#
# The functional suite is hermetic — it builds a sandbox and never reads the
# machine. `pick_app` cannot be: it scans /Applications and every /Users/* home,
# and it starts a BACKGROUND SUBSHELL whose results cross back through a temp
# file. That process boundary is the part with no test coverage, and in 0.15.1
# it shipped a crash: `startup_discover` sets LF_KEPT inside the subshell, the
# header reads it outside, and `set -u` killed the picker after it had already
# printed the whole menu. Rows crossed the boundary; the count did not.
#
# The check that missed it called `startup_discover` directly in the same shell —
# the path that never runs in production. So: exercise the real one.
#
# Non-root, so it sees only this account (enough — the boundary is the same).
# Empty input is a clean cancel; nothing is ever moved.
#
#   bash scripts/picker-smoke.sh     -> prints the menu, exits 0
set -u
cd "$(dirname "${BASH_SOURCE[0]}")/.." || exit 1

export SHEERSWEEP_LIB=1
# shellcheck disable=SC2034  # read by the sourced script, not by this one
REAL_HOME="$HOME"
# shellcheck disable=SC2034  # ditto
DRY=1
# shellcheck source=/dev/null
source ./sheersweep

out="$(printf '\n' | pick_app 2>&1)"; rc=$?
printf '%s\n' "$out"
echo ""

fail=0
check() {   # $1 = label  $2 = 0/1
  if [ "$2" -eq 1 ]; then printf '   [ PASS ] %s\n' "$1"
  else printf '   [ FAIL ] %s\n' "$1"; fail=1; fi
}

check "the picker completes without dying" "$([ "$rc" -eq 0 ] && echo 1 || echo 0)"
case "$out" in *"unbound variable"*) check "no unbound variable across the scan boundary" 0 ;;
               *)                    check "no unbound variable across the scan boundary" 1 ;; esac
case "$out" in *"Apps you can uninstall"*) check "the app section rendered" 1 ;;
               *)                          check "the app section rendered" 0 ;; esac
# `{tot}` still in the text means a placeholder never got its value — the exact
# shape of a fact that failed to cross the boundary.
case "$out" in *"{tot}"*|*"{n}"*) check "every placeholder was filled" 0 ;;
               *)                 check "every placeholder was filled" 1 ;; esac

echo ""
if [ "$fail" -eq 0 ]; then
  echo "[ PASS ] picker-smoke"
else
  echo "[ FAIL ] picker-smoke" >&2
  exit 1
fi
