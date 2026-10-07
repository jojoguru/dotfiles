#!/usr/bin/env bash
# Holt den aktuellen Stand von diesem Mac ins Repo (System -> Repo).
# Committet nichts: danach mit `git diff` prüfen und selbst committen.
# Bricht mit Exit 1 ab, wenn der Secret-Scan anschlägt.

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
source "$REPO/lib/common.sh"

# Secret-Scan vor jedem Commit in diesem Repo
git -C "$REPO" config core.hooksPath .githooks

step "Dateien einsammeln"
for entry in "${FILES[@]}"; do
  rel="${entry%%|*}"
  src="${entry#*|}"
  if [[ ! -f "$src" ]]; then
    warn "fehlt auf diesem Mac, übersprungen: $src"
    continue
  fi
  mkdir -p "$(dirname "$REPO/$rel")"
  cp "$src" "$REPO/$rel"
  say "$rel"
done

step "cmux-Einstellungen aus den macOS-Defaults"
python3 "$REPO/lib/cmux_defaults.py" export "$REPO/$CMUX_DEFAULTS"
say "$CMUX_DEFAULTS"

step "Secret-Scan"
"$REPO/lib/secret-scan.sh"
say "keine Auffälligkeiten"

step "Änderungen"
if [[ -z "$(git -C "$REPO" status --porcelain)" ]]; then
  say "keine, das Repo ist aktuell"
else
  git -C "$REPO" status --short
  printf '\n  Prüfen mit `git diff`, dann committen und pushen.\n'
fi
