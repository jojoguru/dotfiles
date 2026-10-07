#!/usr/bin/env bash
# Richtet cmux, zsh, Starship & Co. aus diesem Repo auf einem Mac ein
# (Repo -> System). Vorhandene Dateien, die sich unterscheiden, werden vorher
# nach ~/.dotfiles-backup/<zeitstempel>/ gesichert. Mehrfach ausführbar.
#
#   ./install.sh             alles einrichten
#   ./install.sh --dry-run   nur anzeigen, was passieren würde
#   ./install.sh --no-brew   Homebrew-Pakete überspringen

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
source "$REPO/lib/common.sh"

DRY_RUN=0
NO_BREW=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --no-brew) NO_BREW=1 ;;
    *) sed -n '2,8s/^# \{0,1\}//p' "$0"; exit 2 ;;
  esac
done

BACKUP_DIR="$HOME/.dotfiles-backup/$(date +%Y%m%d-%H%M%S)"
backed_up=0

run() {
  if ((DRY_RUN)); then say "[dry-run] $*"; else "$@"; fi
}

# Sichert eine vorhandene Datei unter BACKUP_DIR, Pfad relativ zu $HOME
backup_existing() {
  local target="$BACKUP_DIR/${1#"$HOME"/}"
  run mkdir -p "$(dirname "$target")"
  run cp -p "$1" "$target"
  backed_up=1
}

install_file() {
  local src="$1" dst="$2"
  if [[ -f "$dst" ]] && cmp -s "$src" "$dst"; then
    say "unverändert: $dst"
    return
  fi
  [[ -e "$dst" ]] && backup_existing "$dst"
  run mkdir -p "$(dirname "$dst")"
  run cp "$src" "$dst"
  say "installiert: $dst"
}

clone_if_missing() {
  if [[ -d "$2" ]]; then
    say "vorhanden: $2"
  else
    run git clone --depth 1 "$1" "$2"
  fi
}

# Secret-Scan vor jedem Commit in diesem Repo
run git -C "$REPO" config core.hooksPath .githooks

step "Homebrew-Pakete (Brewfile)"
if ((NO_BREW)); then
  say "übersprungen (--no-brew)"
elif ! command -v brew >/dev/null; then
  warn "Homebrew fehlt. Zuerst installieren (https://brew.sh), dann erneut starten."
  exit 1
else
  # Nur Fehlendes installieren, nichts nebenbei aktualisieren. Scheitert ein
  # Paket (z. B. deaktivierte Formel), trotzdem mit den Dateien weitermachen.
  if ! run brew bundle install --no-upgrade --file "$REPO/Brewfile"; then
    warn "Nicht alle Pakete aus dem Brewfile installiert (siehe oben), weiter ohne sie."
  fi
fi

step "oh-my-zsh und Plugins"
ZSH_CUSTOM_DIR="$HOME/.oh-my-zsh/custom"
clone_if_missing https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
clone_if_missing https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM_DIR/plugins/zsh-autosuggestions"
clone_if_missing https://github.com/enrico9034/watch-plugin-zsh.git "$ZSH_CUSTOM_DIR/plugins/watch"

step "Konfigurationsdateien"
for entry in "${FILES[@]}"; do
  src="$REPO/${entry%%|*}"
  dst="${entry#*|}"
  if [[ "$src" == */iterm2/* && ! -d "$HOME/Library/Application Support/iTerm2" ]]; then
    say "übersprungen (iTerm2 nicht installiert): $dst"
    continue
  fi
  install_file "$src" "$dst"
done
run chmod +x "$HOME/.claude/statusline-usage.sh" "$HOME/.claude/statusline-tokens.sh" \
  "$HOME/.claude/claude-usage-panel.sh"

step "Platzhalter für Secret-Dateien"
for f in "${SECRET_FILES[@]}"; do
  if [[ -e "$f" ]]; then
    say "vorhanden: $f"
    continue
  fi
  if ((DRY_RUN)); then
    say "[dry-run] Platzhalter anlegen: $f"
  else
    mkdir -p "$(dirname "$f")"
    printf '# Secrets (Tokens etc.), bewusst nicht im dotfiles-Repo.\n# Inhalt aus dem Passwort-Manager wiederherstellen.\n' >"$f"
    chmod 600 "$f"
  fi
  warn "Platzhalter angelegt, Tokens selbst eintragen: $f"
done

step "cmux-Darstellung (macOS-Defaults)"
if pgrep -xq cmux; then
  warn "cmux läuft, übersprungen. cmux beenden (⌘Q) und ./install.sh --no-brew erneut starten."
else
  if defaults export com.cmuxterm.app - >/dev/null 2>&1; then
    run mkdir -p "$BACKUP_DIR"
    run defaults export com.cmuxterm.app "$BACKUP_DIR/com.cmuxterm.app.plist"
    backed_up=1
  fi
  run python3 "$REPO/lib/cmux_defaults.py" import "$REPO/$CMUX_DEFAULTS"
  say "übernommen: $CMUX_DEFAULTS"
fi

step "Claude-Code-Statusline (Usage-Pill in der cmux-Sidebar, Session-Tokens)"
settings="$HOME/.claude/settings.json"
script="$HOME/.claude/statusline-usage.sh"
if ! command -v jq >/dev/null; then
  warn "jq fehlt, übersprungen."
else
  current="$(cat "$settings" 2>/dev/null || echo '{}')"
  updated="$(jq --arg cmd "$script" '
    .statusLine = {type: "command", command: $cmd, refreshInterval: 60}
    | .hooks.SessionEnd = ((.hooks.SessionEnd // [])
        | if any(.[]; any(.hooks[]?; .command == ($cmd + " --clear"))) then .
          else . + [{hooks: [{type: "command", command: ($cmd + " --clear"), timeout: 10}]}]
          end)
  ' <<<"$current")"
  if [[ "$(jq -S . <<<"$current")" == "$(jq -S . <<<"$updated")" ]]; then
    say "unverändert: $settings"
  elif ((DRY_RUN)); then
    say "[dry-run] statusLine + SessionEnd-Hook in $settings eintragen"
  else
    [[ -f "$settings" ]] && backup_existing "$settings"
    mkdir -p "$(dirname "$settings")"
    printf '%s\n' "$updated" >"$settings"
    say "aktualisiert: $settings"
  fi
fi

step "Fertig"
((backed_up)) && ! ((DRY_RUN)) && say "Vorherige Dateien gesichert in $BACKUP_DIR"
say "Neue Shell starten (exec zsh) und cmux neu starten, damit Akzent und Font greifen."
