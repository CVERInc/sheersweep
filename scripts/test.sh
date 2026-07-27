#!/usr/bin/env bash
# Single entry point — the SAME checks GitHub Actions runs, so local and CI agree.
# Mirrors .github/workflows: shellcheck · syntax · sudo-free smoke · CHANGELOG gate.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "→ shellcheck"; shellcheck sheersweep scripts/func-test.sh
echo "→ syntax";     bash -n sheersweep
echo "→ smoke (no sudo)"; chmod +x sheersweep; ./sheersweep --version; ./sheersweep --help >/dev/null
echo "→ CHANGELOG has the script version"
v="$(grep -E '^VERSION=' sheersweep | head -1 | sed -E 's/.*"([0-9.]+)".*/\1/')"
grep -q "## \[$v\]" CHANGELOG.md || { echo "CHANGELOG.md missing section for $v"; exit 1; }

# Functional regression tests for the uninstall/restore edge cases. They use
# macOS-only tools (`stat -f`, `find -print0`, `sort -z`), so run them only on
# Darwin — CI on Linux keeps the static checks above and skips these.
if [ "$(uname -s)" = "Darwin" ]; then
  echo "→ functional tests (macOS)"; bash scripts/func-test.sh
else
  echo "→ functional tests (skipped — not macOS)"
fi
echo "[ PASS ] ALL GREEN ($v)"
