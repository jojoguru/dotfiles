#!/usr/bin/env bash
# Claude-Code-Statusline: spiegelt die claude.ai-Nutzungslimits (5h / 7 Tage)
# als Pill in die cmux-Sidebar des Workspaces, in dem Claude läuft.
#
# Datenquelle ist `rate_limits` aus dem Statusline-JSON von Claude Code
# (offiziell dokumentiert, kein eigener API-Call, kein Token). Ein gemeinsamer
# Cache führt die Werte aller Sessions zusammen, damit jeder Claude-Workspace
# den neuesten Stand zeigt, auch wenn dort gerade nichts passiert.
#
#   statusline-usage.sh           Statusline-Modus (JSON auf stdin)
#   statusline-usage.sh --clear   Pill im aktuellen Workspace entfernen (SessionEnd-Hook)
#   statusline-usage.sh --show    zusammengeführten Stand ausgeben (zum Testen)
#
# Die Zeile mit den Session-Tokens kommt aus statusline-tokens.sh; nur dessen
# Ausgabe landet in der Claude-Code-Statusline.

set -u

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/claude-usage"
CACHE="$CACHE_DIR/rate-limits.json"
STATUS_KEY="claude_usage"
ICON="gauge.with.dots.needle.33percent"
CMUX_BIN="${CMUX_BUNDLED_CLI_PATH:-cmux}"
WS="${CMUX_WORKSPACE_ID:-}"
MARKER="$CACHE_DIR/pushed.${WS:-none}"
# Pill auch ohne Änderung neu setzen, falls cmux sie verloren hat (z. B. Neustart)
REPUSH_MINUTES=10

mkdir -p "$CACHE_DIR"

if [[ "${1:-}" == "--clear" ]]; then
  rm -f "$MARKER"
  [[ -n "$WS" ]] && "$CMUX_BIN" clear-status "$STATUS_KEY" --workspace "$WS" >/dev/null 2>&1
  exit 0
fi

if [[ "${1:-}" == "--show" ]]; then
  input='{}'
else
  input="$(cat)"
  "${BASH_SOURCE[0]%/*}/statusline-tokens.sh" <<<"$input"
fi
old="$(cat "$CACHE" 2>/dev/null)"

# Zusammenführen: gleiches Fenster (resets_at ±10 min) → höherer Prozentwert,
# sonst gewinnt das neuere Fenster; abgelaufene Fenster fallen weg.
# Ausgabe: Zeile 1 = neuer Cache, Zeile 2 = Pill-Text, Zeile 3 = Farbe.
{ IFS= read -r merged; IFS= read -r label; IFS= read -r color; } < <(
  jq -r --arg oldraw "$old" --argjson now "$(date +%s)" '
    def win:
      if type == "object" and (.used_percentage | type) == "number"
         and (.resets_at | type) == "number" and .resets_at > $now
      then {used_percentage, resets_at} else null end;
    def pick($a; $b):
      if $a == null then $b
      elif $b == null then $a
      elif (($a.resets_at - $b.resets_at) | fabs) > 600 then
        (if $a.resets_at > $b.resets_at then $a else $b end)
      else {used_percentage: ([$a.used_percentage, $b.used_percentage] | max),
            resets_at: ([$a.resets_at, $b.resets_at] | max)}
      end;
    def pct: .used_percentage | round | tostring + "%";

    (.rate_limits // {}) as $n
    | (($oldraw | try fromjson catch null) // {}) as $o
    | {five_hour: pick($n.five_hour | win; $o.five_hour | win),
       seven_day: pick($n.seven_day | win; $o.seven_day | win),
       updated_at: (if ($n.five_hour | win) or ($n.seven_day | win) then $now
                    else $o.updated_at end)} as $m
    | ([ (if $m.five_hour then "5h " + ($m.five_hour | pct)
            + " ↻" + ($m.five_hour.resets_at | strflocaltime("%H:%M")) else empty end),
         (if $m.seven_day then "7d " + ($m.seven_day | pct) else empty end)
       ] | join(" · ")) as $label
    | ([$m.five_hour.used_percentage, $m.seven_day.used_percentage]
       | map(select(. != null)) | max // 0) as $hi
    | ($m | tojson),
      $label,
      (if $hi >= 80 then "#EA6962" elif $hi >= 50 then "#D8A657" else "#A9B665" end)
  ' <<<"$input" 2>/dev/null
)

[[ -z "${merged:-}" ]] && exit 0

if [[ "$merged" != "$old" ]]; then
  tmp="$(mktemp "$CACHE_DIR/.rate-limits.XXXXXX")" &&
    printf '%s\n' "$merged" >"$tmp" && mv -f "$tmp" "$CACHE"
fi

if [[ "${1:-}" == "--show" ]]; then
  echo "${label:-(keine Daten)}  [$color]"
  exit 0
fi

# Nur innerhalb von cmux und nur bei Änderung pushen. Im Hintergrund, weil
# Claude Code ein laufendes Statusline-Skript beim nächsten Update abbricht.
[[ -z "$WS" ]] && exit 0
sig="$label|$color"
if [[ "$(cat "$MARKER" 2>/dev/null)" == "$sig" ]] &&
  [[ -n "$(find "$MARKER" -mmin -"$REPUSH_MINUTES" 2>/dev/null)" ]]; then
  exit 0
fi
(
  if [[ -n "$label" ]]; then
    "$CMUX_BIN" set-status "$STATUS_KEY" "$label" --icon "$ICON" \
      --color "$color" --priority 10 --workspace "$WS"
  else
    "$CMUX_BIN" clear-status "$STATUS_KEY" --workspace "$WS"
  fi && printf '%s' "$sig" >"$MARKER"
) >/dev/null 2>&1 &
exit 0
