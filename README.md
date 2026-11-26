# dev-utils

Small command-line tools for day-to-day development. Each tool has its own folder with its own README and installer.

| Tool | What it does |
| --- | --- |
| [new-wt](new-wt/) | Creates a git worktree for a branch and opens it in a herdr tab, with claude and your editor side by side |

## Adding a tool

Give it a folder named after the command, with:

- `bin/`: the commands themselves. The installer links them into `~/.local/bin`, which is on `PATH`.
- `install.sh`: sets the tool up. It should be safe to run more than once.
- `README.md`: what it does and how to use it.

Then add a row to the table above.
