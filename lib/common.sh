# Gemeinsame Definitionen für backup.sh und install.sh.

# Zuordnung Repo-Pfad → Pfad auf dem System. backup.sh kopiert System → Repo,
# install.sh kopiert Repo → System. Nur was hier steht, landet im Repo.
FILES=(
  "cmux/cmux.json|$HOME/.config/cmux/cmux.json"
  "cmux/config.ghostty|$HOME/Library/Application Support/com.cmuxterm.app/config.ghostty"
  "starship/starship.toml|$HOME/.config/starship.toml"
  "zsh/zshrc|$HOME/.zshrc"
  "zsh/zprofile|$HOME/.zprofile"
  "zsh/aliases|$HOME/.aliases"
  "zsh/bash-config/common|$HOME/.bash-config/.common"
  "zsh/bash-config/godot|$HOME/.bash-config/.godot"
  "git/gitconfig|$HOME/.gitconfig"
  "git/gitignore_global|$HOME/.gitignore"
  "claude/statusline-usage.sh|$HOME/.claude/statusline-usage.sh"
  "iterm2/omarchy-gruvbox.json|$HOME/Library/Application Support/iTerm2/DynamicProfiles/omarchy-gruvbox.json"
)

# Werden von der .zshrc gesourced, enthalten aber Tokens und bleiben deshalb
# draußen. install.sh legt nur leere Platzhalter an, damit die Shell startet.
SECRET_FILES=(
  "$HOME/.bash-config/.brainbits"
  "$HOME/.bash-config/.tecsafe"
)

CMUX_DEFAULTS="cmux/defaults.plist"

if [[ -t 1 ]]; then
  _bold=$'\e[1m' _yellow=$'\e[33m' _reset=$'\e[0m'
else
  _bold='' _yellow='' _reset=''
fi

step() { printf '\n%s==> %s%s\n' "$_bold" "$1" "$_reset"; }
say() { printf '  %s\n' "$1"; }
warn() { printf '  %s! %s%s\n' "$_yellow" "$1" "$_reset" >&2; }
