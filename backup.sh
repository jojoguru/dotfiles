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

# Namen, die nur in der ersten Liste stehen ($1, $2: ein Name pro Zeile)
only_in() { comm -23 <(sort -u <<<"$1") <(sort -u <<<"$2") | sed '/^$/d'; }
# Eine Zeile Abweichungen ausgeben, falls es welche gibt
report() {
  if [[ -n "$2" ]]; then warn "$1: $(paste -sd ' ' - <<<"$2")"; fi
}

step "Homebrew-Abgleich mit dem Brewfile"
bf="$REPO/Brewfile"
if ! command -v brew >/dev/null; then
  warn "Homebrew fehlt, übersprungen."
elif ! brew bundle list --all --file "$bf" >/dev/null 2>&1; then
  warn "Brewfile nicht lesbar, übersprungen. Fehler zeigt: brew bundle list --file Brewfile"
else
  # Formeln und Casks ohne Tap-Präfix vergleichen ("dafish/gogo-meta/gogo" -> "gogo")
  want_formulae="$(brew bundle list --formula --file "$bf" 2>/dev/null | sed 's|.*/||')"
  want_casks="$(brew bundle list --cask --file "$bf" 2>/dev/null | sed 's|.*/||')"
  want_taps="$(brew bundle list --tap --file "$bf" 2>/dev/null)"
  casks="$(brew list --cask 2>/dev/null)"
  # Nur explizit installierte Formeln; Abhängigkeiten gehören nicht ins Brewfile
  extra_formulae="$(only_in "$(brew leaves --installed-on-request 2>/dev/null | sed 's|.*/||')" "$want_formulae")"
  extra_casks="$(only_in "$casks" "$want_casks")"
  extra_taps="$(only_in "$(brew tap 2>/dev/null)" "$want_taps")"
  missing="$(only_in "$want_formulae" "$(brew list --formula 2>/dev/null | sed 's|.*/||')")
$(only_in "$want_casks" "$casks")"
  missing="$(sed '/^$/d' <<<"$missing")"

  if [[ -z "$extra_formulae$extra_casks$extra_taps$missing" ]]; then
    say "Brewfile und installierter Stand stimmen überein"
  else
    report "Installiert, nicht im Brewfile (Formeln)" "$extra_formulae"
    report "Installiert, nicht im Brewfile (Casks)" "$extra_casks"
    report "Installiert, nicht im Brewfile (Taps)" "$extra_taps"
    report "Im Brewfile, nicht installiert" "$missing"
    say "Aufnehmen:     brew bundle add [--cask] <name> --file Brewfile"
    say "Entfernen:     brew uninstall [--cask] <name>, brew untap <tap>"
    say "Installieren:  brew bundle install --no-upgrade --file Brewfile"
  fi
fi

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
