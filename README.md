# dotfiles

Terminal-Setup für macOS: cmux (Ghostty-basiert) im Omarchy-Gruvbox-Look, zsh mit
oh-my-zsh, Starship-Prompt im Powerline-Stil, die Claude-Usage-Pill in der
cmux-Sidebar, das Usage-Panel in der cmux-Dock und die Session-Tokens in der
Claude-Code-Statusline.

## Neuer Mac

```sh
# 1. Homebrew installieren: https://brew.sh
# 2. Repo klonen und einrichten
git clone git@github.com:jojoguru/dotfiles.git ~/projects/atvantage/dotfiles
cd ~/projects/atvantage/dotfiles
./install.sh --dry-run   # zeigt nur, was passieren würde
./install.sh
```

`install.sh` kann man beliebig oft ausführen. Dateien, die schon identisch sind,
bleiben unangetastet. Alles, was überschrieben wird, sichert das Skript vorher nach
`~/.dotfiles-backup/<zeitstempel>/`. Die Darstellung von cmux (siehe unten) wird
nur übernommen, wenn cmux nicht läuft. Sonst cmux beenden und
`./install.sh --no-brew` noch einmal starten.

Danach:

1. Die Tokens in `~/.bash-config/.brainbits` eintragen (Passwort-Manager).
   Das Skript legt dort nur einen leeren Platzhalter an.
2. `exec zsh`, cmux neu starten.

## Änderungen sichern

Nie direkt auf `main` committen. Jede Änderung bekommt einen eigenen Worktree,
einen Branch und einen PR gegen `main`:

```sh
git fetch && git worktree add ../dotfiles-<thema> -b <thema> origin/main
cd ../dotfiles-<thema>
./backup.sh     # System -> Repo, inkl. Secret-Scan
git diff        # prüfen
git commit -am "…"
git push -u origin <thema> && gh pr create --base main
```

Nach dem Merge: `git worktree remove ../dotfiles-<thema>`.

## Inhalt

| Repo | System | Was |
|---|---|---|
| `cmux/cmux.json` | `~/.config/cmux/cmux.json` | Shortcuts, Akzent `#D8A657`, 16 Gruvbox-Workspace-Farben, aktiver Workspace nur mit dünnem Rand markiert |
| `cmux/config.ghostty` | `~/Library/Application Support/com.cmuxterm.app/config.ghostty` | Theme Gruvbox Material Dark, JetBrainsMono Nerd Font 13, `font-thicken` |
| `cmux/dock.json` | `~/.config/cmux/dock.json` | Legt das Usage-Panel in neuen Fenstern automatisch in der rechten Dock an |
| `cmux/defaults.plist` | macOS-Defaults `com.cmuxterm.app` | Sidebar-Optik und Graphit-Systemakzent für die Tab-Markierung (nur eine Whitelist, siehe `lib/cmux_defaults.py`) |
| `starship/starship.toml` | `~/.config/starship.toml` | Powerline-Prompt nach „Gort!“, Palette `omarchy_gruvbox` |
| `zsh/zshrc`, `zprofile`, `aliases` | `~/.zshrc`, `~/.zprofile`, `~/.aliases` | Shell-Konfiguration |
| `zsh/bash-config/*` | `~/.bash-config/.common`, `.godot` | Includes der `.zshrc` ohne Secrets |
| `git/gitconfig`, `gitignore_global` | `~/.gitconfig`, `~/.gitignore` | Git-Defaults, Alias `git hist` |
| `claude/statusline-usage.sh` | `~/.claude/statusline-usage.sh` | 5h/7d-Limits als Pill in der cmux-Sidebar; `install.sh` trägt dazu `statusLine` und einen SessionEnd-Hook in `~/.claude/settings.json` ein |
| `claude/statusline-tokens.sh` | `~/.claude/statusline-tokens.sh` | Tokens der laufenden Session als Zeile in der Claude-Code-Statusline (`⛁ 81k out · 325k in · 17,7M cache · 89 calls · ctx 29%`), summiert aus dem Transkript inkl. Subagents; wird von `statusline-usage.sh` aufgerufen |
| `claude/claude-usage-panel.sh` | `~/.claude/claude-usage-panel.sh` | Dock-Panel mit Balken für 5h/7d, Tempo-Marke, Reset-Countdown und Datenstand; liest nur den Cache der Statusline (Tasten `r`, `q`) |
| `iterm2/omarchy-gruvbox.json` | iTerm2 DynamicProfiles | Altes iTerm-Profil, wird nur installiert, wenn iTerm2 vorhanden ist |
| `Brewfile` | | cmux, Nerd Font, Starship, jq und die Tools, die `.zshrc` beim Start erwartet |

oh-my-zsh sowie die Plugins `zsh-autosuggestions` und `watch` klont `install.sh` direkt von GitHub.

## Secrets

Tokens gehören nicht in dieses Repo. Drei Sicherungen sorgen dafür:

- **Whitelist:** Ins Repo kommt nur, was in `lib/common.sh` (`FILES`) und
  `lib/cmux_defaults.py` (`KEYS`) steht. `~/.bash-config/.brainbits` enthält
  Tokens und ist deshalb bewusst nicht dabei.
- **Scan:** `backup.sh` bricht ab, wenn `lib/secret-scan.sh` etwas findet
  (GitHub-/GitLab-/AWS-/Slack-Tokens, `sk-…`-Keys, Private Keys, Zuweisungen an
  `*_TOKEN`/`*_SECRET`/`*_PASSWORD`). Ausgegeben werden nur Datei und Zeile.
- **Pre-commit-Hook:** `.githooks/pre-commit` scannt die gestagten Inhalte.
  Aktiv wird er durch `git config core.hooksPath .githooks`; das erledigen
  `install.sh` und `backup.sh`. Nach einem frischen Klon also einmal eins der
  beiden Skripte laufen lassen.

## Stolperfallen

- cmux schreibt `cmux.json` und `config.ghostty` neu, wenn man etwas in den
  Settings ändert. Deshalb kopiert das Setup Dateien, statt Symlinks anzulegen.
  Nach Änderungen in der UI einfach `./backup.sh` laufen lassen.
- Die Tab-Markierung in cmux folgt dem macOS-Akzent, nicht `app.accentColor`.
  Darum setzt `defaults.plist` nur für cmux den Akzent auf Graphit
  (`AppleAccentColor -1`, `AppleAquaColorVariant 6`). Das greift erst nach
  einem Neustart von cmux.
- Für die Rand-Markierung in der Sidebar darf `workspaceColors.selectionColor`
  nicht gesetzt sein: Jede eigene Auswahlfarbe erzwingt eine volle Fläche, und
  `indicatorStyle: "border"` ist nur ein Alias für `solidFill`.
- `dock.json` enthält den absoluten Pfad `/Users/jostvolker/.claude/…`. Bei
  einem anderen Benutzernamen dort anpassen. Bestehende Fenster stellen ihre
  Dock aus dem Session-Snapshot wieder her, das Panel erscheint also nur in
  neuen Fenstern automatisch.
- `cmux config doctor` meldet Fehler bei den Shortcuts, weil die Settings-UI sie
  als Objekte speichert. cmux liest sie trotzdem.
- `.bash-config/.brainbits` exportiert `GITHUB_TOKEN`. Ist der Token ungültig,
  schlägt `gh` fehl, obwohl man per Keyring eingeloggt ist. Abhilfe:
  `GITHUB_TOKEN= gh …`
