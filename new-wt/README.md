# new-wt

Create a git worktree for a branch and open it in a new [herdr](https://herdr.dev) tab: claude on the left, your editor (or anything else) on the right. It works in any repo.

```sh
new wt feat/WEB-198-editable-nav-bar                          # tab and claude conversation named "WEB-198-editable-nav-bar"
new wt feat/WEB-198-editable-nav-bar "WEB-198 nav"            # custom name
new wt feat/WEB-198-editable-nav-bar --prompt "Plan {issue}"  # claude starts on this right away
new wt fix/typo --right lazygit --base origin/main
```

`new wt …` is a shortcut for `new-wt …`. See `new-wt --help` for every option.

## Files

- `bin/new-wt`: the command itself
- `install.sh`: sets it up for your shell
- `shell/new.fish`, `shell/new.sh`: the `new wt` shortcut for fish, and for zsh and bash

## Install

From the root of dev-utils:

```sh
new-wt/install.sh               # sets up every shell you use
new-wt/install.sh --shell zsh   # sets up only fish, zsh or bash
```

"Every shell you use" means your login shell, the shell you run the installer from, and any of fish, zsh and bash with its own startup file in your home folder (`~/.config/fish/`, `~/.zshrc`, `~/.bashrc` or `~/.bash_profile`). The settings questions are asked once for all of them.

For each shell, the installer:

- links `bin/new-wt` into `~/.local/bin`, so a `git pull` updates it
- adds `~/.local/bin` to `PATH` if a new terminal of that shell doesn't have it
- sets up the `new wt` shortcut: links `shell/new.fish` for fish, sources `shell/new.sh` from zsh's or bash's startup file
- asks what to open in the right-hand pane and what claude's first message should be
- warns if a new terminal can't find something new-wt needs (git, jq, herdr, claude, pnpm)

It only adds what's missing, so it's safe to run again. Its changes to your shell's startup file sit between `# >>> new-wt >>>` and `# <<< new-wt <<<`, and each run rewrites them. If you move this folder, run the installer again and it points everything at the new place.

## Settings

The installer saves your answers in `~/.config/new-wt/config`. Edit that file or run the installer again to change them.

- `RIGHT_PANE`: command for the right-hand pane, e.g. `nvim`, `lazygit` or `code .`. Use `shell` for a plain shell, or `none` for no right pane. Default `nvim`.
- `CLAUDE_PROMPT`: first message for claude in each new worktree, so it starts working right away. `{issue}` becomes the issue key in the branch name (`WEB-198` in `feat/WEB-198-editable-nav-bar`), `{branch}` the branch and `{title}` the title. When a prompt uses `{issue}` and the branch has no key, the prompt isn't sent. Reopening an existing worktree never sends it. Default: none.
- `CLAUDE_ARGS`: extra flags for claude, e.g. `--permission-mode plan`.

`--prompt` and `--right` override these for one run.

## What it does

1. Creates `<repo>/.worktrees/<branch, with / turned into ->` (and `.worktrees/` itself, adding it to `.git/info/exclude` if the repo doesn't ignore it). If the branch already exists locally or on origin, it checks that out. You can name an origin branch the way `git branch -r` lists it: `origin/feat/x` (or `remotes/origin/feat/x`) checks out `feat/x`. Otherwise it creates a new branch with no upstream, so a first push can't land on the base branch. If the branch already has a worktree, wherever it is, the script reuses it.
2. Makes a new branch from `git config wt.base` if that is set, else `origin/dev` if it exists, else origin's default branch.
3. Copies local-only files from the main checkout: `.claude/settings.local.json`, plus any ignored `.env`, `.env.*`, `.dev.vars` or `*.tfvars` files. It symlinks `.scratch`, `CLAUDE.local.md` and `docs/agents`. It never overwrites a file the worktree already has. The lists are at the top of `bin/new-wt`.
4. Runs `pnpm install --frozen-lockfile` if the repo has a `pnpm-lock.yaml` and the worktree has no `node_modules` yet.
5. When run inside herdr, opens a tab in the current workspace with claude on the left (named after the title) and `RIGHT_PANE` on the right.
