#!/usr/bin/env bash
# Sucht nach Tokens, Keys und Passwörtern. Gibt nur Datei und Zeilennummer
# aus, nie den Fund selbst (damit nichts in Logs oder im Terminal landet).
#
#   lib/secret-scan.sh            alle Dateien im Repo (inkl. ungetrackter)
#   lib/secret-scan.sh --staged   gestagte Inhalte (pre-commit-Hook)
#   lib/secret-scan.sh <datei>…   einzelne Dateien
#
# Exit 1 bei Verdacht. Die Muster sind so formuliert, dass sie sich nicht
# selbst finden; diese Datei wird also ganz normal mitgescannt.

set -uo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

# "Bezeichnung|Regex (ERE)"
PATTERNS=(
  'GitHub-Token|(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}'
  'GitHub-Token|github_pat_[A-Za-z0-9_]{20,}'
  'GitLab-Token|glpat-[A-Za-z0-9_-]{16,}'
  'API-Key (sk-…)|sk-[A-Za-z0-9_-]{20,}'
  'AWS-Key|AKIA[0-9A-Z]{16}'
  'Slack-Token|xox[abprs]-[A-Za-z0-9-]{10,}'
  'Private Key|-----BEGIN [A-Z ]*PRIVATE KEY-----'
  'Zuweisung an *_TOKEN/*_SECRET/…|(TOKEN|SECRET|PASSWORD|PASSWD|API_?KEY)[A-Z0-9_]*[[:space:]]*[:=][[:space:]]*["'"'"']?[A-Za-z0-9/+_.-]{16,}'
  'JSON-Wert token/secret/password|"[A-Za-z_]*([Tt]oken|[Ss]ecret|[Pp]assword|[Aa]pi_?[Kk]ey)"[[:space:]]*:[[:space:]]*"[^"$]{8,}"'
)

hits=0
# Temp-Datei statt Variable, damit auch Binärdateien (NUL-Bytes) vollständig gescannt werden
buf="$(mktemp)"
trap 'rm -f "$buf"' EXIT

# $1 = Name für die Ausgabe, Inhalt kommt über stdin
scan() {
  local name="$1" p label re lines
  cat >"$buf"
  for p in "${PATTERNS[@]}"; do
    label="${p%%|*}"
    re="${p#*|}"
    lines="$(grep -anE -e "$re" "$buf" | cut -d: -f1 | paste -sd, -)"
    if [[ -n "$lines" ]]; then
      echo "  $name:$lines  ($label)" >&2
      hits=1
    fi
  done
}

if [[ "${1:-}" == "--staged" ]]; then
  while IFS= read -r -d '' f; do
    scan "$f" < <(git -C "$ROOT" show ":$f")
  done < <(git -C "$ROOT" diff --cached --name-only --diff-filter=ACMR -z)
elif (($#)); then
  for f in "$@"; do scan "$f" <"$f"; done
else
  while IFS= read -r -d '' f; do
    scan "$f" <"$ROOT/$f"
  done < <(git -C "$ROOT" ls-files -co --exclude-standard -z)
fi

if ((hits)); then
  echo "Secret-Verdacht! Fundstellen oben (ohne Inhalt). Nichts committen, erst bereinigen." >&2
  exit 1
fi
exit 0
