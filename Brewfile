# Alle Homebrew-Pakete dieses Macs, von Hand gepflegt (kein `brew bundle dump`).
# Neues Paket: brew bundle add [--cask] <name> --file Brewfile
# Abweichungen zum installierten Stand zeigt ./backup.sh.

tap "dafish/gogo-meta"

# Terminal
cask "cmux"
cask "font-jetbrains-mono-nerd-font"
cask "claude-code"       # claude/: Statusline und Usage-Panel
brew "starship"
brew "jq"                # claude/statusline-*.sh, install.sh
brew "git"
brew "git-lfs"           # .gitconfig: filter.lfs.required = true
brew "gh"

# Von .zshrc / .zprofile / .aliases und den oh-my-zsh-Plugins vorausgesetzt
brew "php"               # .zshrc liest beim Start die PHP-Version
brew "composer"          # PATH ~/.composer/vendor/bin, Alias nov-clean-restart
brew "node"              # Plugins npm, node
brew "kubernetes-cli"    # Alias k, Plugin kubectl
brew "kubectx"           # Aliase kctx, kns
brew "krew"              # PATH ~/.krew/bin
brew "minio-mc"          # Completion für `mc`; deprecated, ab 2027-07-17 deaktiviert
brew "watch"             # Plugin watch
cask "orbstack"          # .zprofile, docker/docker-compose, Aliase dc, dt8x
cask "sublime-text"      # subl: EDITOR per SSH, Aliase zshconf & Co.
cask "jetbrains-toolbox" # .zprofile: PATH der Toolbox-Skripte

# Cloud, Kubernetes, Container
brew "awscli"
brew "azure-cli"
brew "helm"
brew "dive"
brew "trivy"

# Entwicklung
brew "golangci-lint"
brew "powershell"
brew "mkcert"
brew "direnv"

# Shell-Werkzeuge
brew "fzf"
brew "ripgrep"
brew "the_silver_searcher"
brew "yq"
brew "htop"
brew "wget"
brew "imagemagick"
brew "ghostscript"       # ImageMagick: PDF und PostScript
brew "tailscale"

# Apps: Entwicklung
cask "dafish/gogo-meta/gogo"
cask "codex"
cask "iterm2"
cask "bruno"
cask "postman"
cask "rapidapi"
cask "mockoon"
cask "tableplus"
cask "freelens"
cask "openlens"
cask "dotnet-sdk"
cask "godot"
cask "blender"
cask "lm-studio-bionic"

# Apps: Alltag
cask "alfred"
cask "rectangle"
cask "swiftbar"
cask "bitwarden"
cask "obsidian"
cask "signal"
