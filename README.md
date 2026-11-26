# dev-utils

Small command-line tools for day-to-day development.

## Setup

Each script in `bin/` is symlinked into a directory on `PATH`, and each fish function into fish's function directory:

```sh
ln -s ~/CODE/dev-utils/bin/new-wt ~/.local/bin/new-wt
ln -s ~/CODE/dev-utils/fish/functions/new.fish ~/.config/fish/functions/new.fish
```

## new-wt

Create a git worktree for a branch and open it in a new herdr tab, with claude on the left and nvim on the right. It works in any repo.

```sh
new-wt feat/WEB-198-editable-nav-bar              # tab and claude conversation named "WEB-198-editable-nav-bar"
new-wt feat/WEB-198-editable-nav-bar "WEB-198 nav" # custom name
new-wt --base origin/main fix/typo                 # start a new branch from somewhere else
```

The fish function `new` (`fish/functions/new.fish`) runs it as `new wt …`.

What it does:

1. Creates `<repo>/.worktrees/<branch, with / turned into ->`. If the branch already exists locally or on origin, it checks that out. Otherwise it creates a new branch with no upstream, so a first push can't land on the base branch. If the branch already has a worktree, wherever it is, the script reuses it.
2. Makes a new branch from `git config wt.base` if that is set, else `origin/dev` if it exists, else origin's default branch.
3. Copies local-only files from the main checkout: `.claude/settings.local.json`, plus any ignored `.env`, `.env.*`, `.dev.vars` or `*.tfvars` files. It symlinks `.scratch`, `CLAUDE.local.md` and `docs/agents`. It never overwrites a file the worktree already has. The lists are at the top of the script.
4. Runs `pnpm install --frozen-lockfile` if the repo has a `pnpm-lock.yaml` and the worktree has no `node_modules` yet.
5. When run inside herdr, opens a tab in the current workspace: `claude --name '<title>'` on the left, `nvim` on the right.

Options: `--base REF`, `--no-open` (skip the tab), `--no-focus` (open the tab without switching to it). See `new-wt --help`.
