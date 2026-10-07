#!/usr/bin/env bash
# Token-Verbrauch der laufenden Claude-Code-Session als Zeile in der
# Claude-Code-Statusline, z. B. „⛁ 81k out · 325k in · 17,7M cache · 89 calls · ctx 29%“
# (in = input + cache_write, cache = cache_read).
#
# Wird von statusline-usage.sh mit dem Statusline-JSON auf stdin aufgerufen.
# Die Summen kommen aus dem Transkript (inkl. Subagents), denn
# context_window.total_*_tokens enthält nur die letzte Anfrage, nicht die
# ganze Session (geprüft mit 2.1.285). Die Kontextfüllung kommt direkt aus dem
# Statusline-JSON.
#
#   statusline-tokens.sh                     Statusline-Modus (JSON auf stdin)
#   statusline-tokens.sh --show TRANSKRIPT   Summen eines Transkripts ausgeben (zum Testen)

set -u

# Summen über Haupt- und Subagent-Transkripte. Claude Code schreibt die usage
# in jede Zeile einer Antwort (eine pro Content-Block), frühere Zeilen mit
# vorläufigem output_tokens. Deshalb zählt pro message.id + requestId nur die
# Zeile mit dem höchsten Output.
totals() {
  local transcript="$1" files=()
  [[ -f "$transcript" ]] || return 0
  files=("$transcript")
  for f in "${transcript%.jsonl}"/subagents/*.jsonl; do
    [[ -f "$f" ]] && files+=("$f")
  done
  grep -hF '"usage"' "${files[@]}" 2>/dev/null | jq -ncR '
    [inputs | fromjson? | select(.type == "assistant" and (.message.usage | type) == "object")
     | {k: (if .message.id or .requestId
            then (.message.id // "") + ":" + (.requestId // "") else .uuid end),
        u: .message.usage}]
    | group_by(.k) | map(max_by(.u.output_tokens // 0).u)
    | {calls: length,
       input: (map(.input_tokens // 0) | add // 0),
       output: (map(.output_tokens // 0) | add // 0),
       cache_write: (map(.cache_creation_input_tokens // 0) | add // 0),
       cache_read: (map(.cache_read_input_tokens // 0) | add // 0)}'
}

if [[ "${1:-}" == "--show" ]]; then
  totals "${2:?Pfad zum Transkript fehlt}"
  exit 0
fi

input="$(cat)"
tot="$(totals "$(jq -r '.transcript_path // empty' <<<"$input" 2>/dev/null)")"
[[ -z "$tot" ]] && exit 0

jq -r --argjson t "$tot" '
  def h: if . >= 1e6 then (. / 1e5 | round / 10 | tostring) + "M"
         elif . >= 1e4 then (. / 1e3 | round | tostring) + "k"
         elif . >= 1e3 then (. / 1e2 | round / 10 | tostring) + "k"
         else tostring end | gsub("\\."; ",");
  def rgb($r; $g; $b): "\u001b[38;2;\($r);\($g);\($b)m";
  (rgb(146; 131; 116)) as $dim | (rgb(212; 190; 152)) as $fg
  | .context_window.used_percentage as $ctx
  | select(($t.calls // 0) > 0)
  | [ "\($fg)\($t.output | h)\($dim) out",
      "\($fg)\($t.input + $t.cache_write | h)\($dim) in",
      "\($fg)\($t.cache_read | h)\($dim) cache",
      "\($fg)\($t.calls)\($dim) calls",
      (if $ctx then
         (if $ctx >= 80 then rgb(234; 105; 98) elif $ctx >= 50 then rgb(216; 166; 87)
          else rgb(169; 182; 101) end) + "ctx \($ctx | round)%\($dim)"
       else empty end)
    ] | "\($dim)⛁ " + join(" · ") + "\u001b[0m"
' <<<"$input" 2>/dev/null
exit 0
