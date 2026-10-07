# CLAUDE.md

macOS dotfiles: cmux, zsh, Starship, git, Claude statusline. Files are **copied**, not symlinked.

## Workflow (mandatory)

Never commit or push to `main`. Every change gets its own worktree, branch and PR against `main`. Worktrees live under `.claude/worktrees/` (gitignored); run these from the main checkout, not from inside another worktree:

```sh
git fetch && git worktree add .claude/worktrees/dotfiles-<topic> -b <topic> origin/main
# work + commit inside .claude/worktrees/dotfiles-<topic>
git push -u origin <topic> && gh pr create --base main
git worktree remove .claude/worktrees/dotfiles-<topic>   # after merge
```

## Sync

- `./install.sh`: repo → system. Changes the live Mac, so only run with `--dry-run` unless asked.
- `./backup.sh`: system → repo, runs the secret scan, reports Brewfile drift, never commits.
- `Brewfile` is curated by hand: no `brew bundle dump` into it (pulls in leftover libraries), never run `brew bundle cleanup` (uninstalls apps).
- Only whitelisted paths are synced: `FILES` in `lib/common.sh`, `KEYS` in `lib/cmux_defaults.py`. New file → add it there and to the README table.

## Rules

- No secrets. `~/.bash-config/.brainbits` stays out. Never bypass the pre-commit scan (`--no-verify`).
- Scripts: bash, `set -euo pipefail`, idempotent, shared helpers in `lib/common.sh`.
- Comments, README and commit messages are in German.
- `gh` fails on a stale `GITHUB_TOKEN`: run `GITHUB_TOKEN= gh …`.
