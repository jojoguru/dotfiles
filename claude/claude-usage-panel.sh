#!/usr/bin/env bash
# cmux-Dock-Panel: Claude-Nutzungslimits (5h / 7 Tage) mit Balken, Tempo-Marke
# und Countdown bis zum Reset. Liest nur den Cache, den die Statusline
# ~/.claude/statusline-usage.sh schreibt; kein Netzwerk, kein Token.
#
# Tempo-Marke │: so weit wäre der Balken bei gleichmäßigem Verbrauch über das
# ganze Fenster. Liegt der Balken rechts davon, verbrauchst du schneller.
#
# Tasten: r = sofort neu zeichnen, q = beenden.

export LC_NUMERIC=C

CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/claude-usage/rate-limits.json"
INTERVAL=5

# Gruvbox Material Dark
FG=$'\e[38;2;212;190;152m'
DIM=$'\e[38;2;146;131;116m'
TRACK=$'\e[38;2;80;73;69m'
GREEN=$'\e[38;2;169;182;101m'
YELLOW=$'\e[38;2;216;166;87m'
RED=$'\e[38;2;234;105;98m'
BOLD=$'\e[1m'
RESET=$'\e[0m'

level_color() { # $1 = Prozent (ganzzahlig)
  if (($1 >= 80)); then printf '%s' "$RED"
  elif (($1 >= 50)); then printf '%s' "$YELLOW"
  else printf '%s' "$GREEN"; fi
}

human_duration() { # $1 = Sekunden
  local s=$1 d h m
  ((s < 0)) && s=0
  d=$((s / 86400)) h=$((s % 86400 / 3600)) m=$((s % 3600 / 60))
  if ((d > 0)); then printf '%dd %dh' "$d" "$h"
  elif ((h > 0)); then printf '%dh %dm' "$h" "$m"
  else printf '%dm' "$m"; fi
}

reset_label() { # $1 = Epoch; heute nur Uhrzeit, sonst Wochentag + Uhrzeit
  if [[ "$(date -r "$1" +%F)" == "$(date +%F)" ]]; then
    date -r "$1" +%H:%M
  else
    LC_ALL=de_DE.UTF-8 date -r "$1" '+%a %H:%M'
  fi
}

# Zeile ausgeben und den Rest der Terminalzeile löschen (flackerfreies Neuzeichnen)
line() { printf ' %s\e[K\n' "$1"; }

render_window() { # $1 Titel, $2 Fensterlänge s, $3 Prozent, $4 resets_at, $5 Breite
  local title=$1 len=$2 pct=$3 reset=$4 w=$5 now p fill pace i bar col right
  now=$(date +%s)

  if [[ -z "$pct" || -z "$reset" || "$reset" -le "$now" ]]; then
    line "${BOLD}${FG}${title}${RESET}"
    line "${TRACK}$(printf '%*s' "$w" '' | sed 's/ /░/g')${RESET}"
    line "${DIM}kein aktives Fenster${RESET}"
    return
  fi

  p=$(printf '%.0f' "$pct")
  fill=$((p * w / 100))
  ((fill > w)) && fill=$w
  pace=$(((now - (reset - len)) * w / len))
  ((pace < 0)) && pace=0
  ((pace >= w)) && pace=$((w - 1))
  col=$(level_color "$p")

  bar=""
  for ((i = 0; i < w; i++)); do
    if ((i == pace)); then bar+="${FG}│"
    elif ((i < fill)); then bar+="${col}█"
    else bar+="${TRACK}░"; fi
  done

  right="${p} %"
  line "${BOLD}${FG}${title}${RESET}$(printf '%*s' $((w - ${#title} - ${#right})) '')${BOLD}${col}${right}${RESET}"
  line "${bar}${RESET}"
  line "${DIM}Reset $(reset_label "$reset") · in $(human_duration $((reset - now)))${RESET}"
}

draw() {
  local cols w f5p f5r s7p s7r upd now age
  # stty statt tput: tput in $(…) sieht keine TTY und meldet pauschal 80 Spalten
  cols=$(stty size </dev/tty 2>/dev/null | cut -d' ' -f2)
  [[ "$cols" =~ ^[0-9]+$ ]] || cols=40
  w=$((cols - 2))
  ((w > 60)) && w=60
  ((w < 12)) && w=12
  now=$(date +%s)

  printf '\e[H'
  line ""
  line "${BOLD}${YELLOW}CLAUDE USAGE${RESET}"
  line ""

  if [[ ! -s "$CACHE" ]]; then
    line "${DIM}Noch keine Daten.${RESET}"
    line "${DIM}Starte eine Claude-Session in cmux,${RESET}"
    line "${DIM}nach der ersten Antwort geht's los.${RESET}"
    printf '\e[J'
    return
  fi

  IFS=$'\t' read -r f5p f5r s7p s7r upd < <(
    jq -r '[.five_hour.used_percentage, .five_hour.resets_at,
            .seven_day.used_percentage, .seven_day.resets_at, .updated_at]
           | map(if . == null then "" else tostring end) | @tsv' "$CACHE" 2>/dev/null
  )

  render_window "Session · 5h" 18000 "$f5p" "$f5r" "$w"
  line ""
  render_window "Woche · 7d" 604800 "$s7p" "$s7r" "$w"
  line ""
  line "${FG}│${DIM} = gleichmäßiges Tempo${RESET}"
  [[ -z "$upd" ]] && upd=$(stat -f %m "$CACHE" 2>/dev/null || echo "$now")
  age=$((now - upd))
  if ((age < 60)); then age="gerade aktualisiert"; else age="Stand vor $(human_duration "$age")"; fi
  line "${DIM}${age} · q beendet${RESET}"
  printf '\e[J'
}

cleanup() { printf '\e[?25h\e[0m\n'; exit 0; }
trap cleanup INT TERM
# WINCH unterbricht das read unten, dadurch wird nach Größenänderung sofort neu gezeichnet
trap ':' WINCH

# Tab-Titel setzen (cmux ignoriert OSC-Titel in der Dock), Cursor ausblenden, Bildschirm leeren
if [[ -n "${CMUX_SURFACE_ID:-}" ]]; then
  "${CMUX_BUNDLED_CLI_PATH:-cmux}" rename-tab --surface "$CMUX_SURFACE_ID" "Claude Usage" >/dev/null 2>&1
fi
printf '\e]0;Claude Usage\a\e[?25l\e[2J'
while :; do
  draw
  # read dient als Wartezeit und fängt gleichzeitig Tasten ab
  if read -rsn1 -t "$INTERVAL" key; then
    [[ "$key" == q ]] && cleanup
  fi
done
