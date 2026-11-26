#!/usr/bin/env bash
# install.sh — set up new-wt for your shells and choose its settings.
#
#   ./install.sh                set up every shell you use
#   ./install.sh --shell zsh    set up only fish, zsh or bash
#
# "Every shell you use" means your login shell, the shell you ran this from,
# and any of fish, zsh and bash with its own startup file in your home folder.
#
# Safe to run again: it only adds what's missing, and asks the questions again
# with your current answers as the defaults. Run it again after moving this
# folder and it repoints everything here.
set -euo pipefail

here=$(cd "$(dirname "$0")" && pwd -P) # this tool's folder: bin/, shell/
bin_dir=$HOME/.local/bin
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
config=$config_home/new-wt/config

say() { printf '→ %s\n' "$*"; }
warn() { printf 'install: %s\n' "$*" >&2; }
die() { warn "$*"; exit 1; }

only=''
while [ $# -gt 0 ]; do
  case $1 in
    --shell) [ $# -ge 2 ] || die "--shell needs fish, zsh or bash"; only=$2; shift 2 ;;
    -h | --help) sed -n '4,12s/^# \{0,1\}//p' "$0"; exit 0 ;;
    *) die "unknown option $1 (see --help)" ;;
  esac
done

# Which shells to set up.
shells=''
add_shell() {
  case " $shells " in *" $1 "*) return 0 ;; esac
  if command -v "$1" >/dev/null; then shells="$shells $1"; fi
}
if [ -n "$only" ]; then
  case $only in fish | zsh | bash) ;; *) die "can't set up $only; use --shell fish, zsh or bash" ;; esac
  command -v "$only" >/dev/null || die "$only isn't installed"
  shells=" $only"
else
  login=$(basename "${SHELL:-}")
  # The process that started this script, e.g. "-zsh" or "/usr/local/bin/fish".
  parent=$(ps -o comm= -p "$PPID" 2>/dev/null | sed 's|.*/||; s|^-||') || true
  for s in fish zsh bash; do
    if [ "$s" = "$login" ] || [ "$s" = "$parent" ]; then add_shell "$s"; fi
  done
  if [ -d "$config_home/fish" ]; then add_shell fish; fi
  if [ -f "${ZDOTDIR:-$HOME}/.zshrc" ] || [ -f "${ZDOTDIR:-$HOME}/.zprofile" ]; then add_shell zsh; fi
  if [ -f "$HOME/.bashrc" ] || [ -f "$HOME/.bash_profile" ]; then add_shell bash; fi
  [ -n "$shells" ] || die "found no fish, zsh or bash to set up; pick one with --shell"
fi

# PATH as a brand-new terminal of $shell_name sees it: its own startup files, nothing inherited.
fresh_path() {
  local cmd='echo "__PATH__$PATH"'
  [ "$shell_name" != fish ] || cmd='echo __PATH__(string join : $PATH)'
  env -i HOME="$HOME" USER="${USER:-}" TERM="${TERM:-xterm-256color}" \
    ${XDG_CONFIG_HOME:+"XDG_CONFIG_HOME=$XDG_CONFIG_HOME"} ${ZDOTDIR:+"ZDOTDIR=$ZDOTDIR"} \
    "$(command -v "$shell_name")" -l -i -c "$cmd" </dev/null 2>/dev/null |
    sed -n 's/^__PATH__//p' | tail -1 || true
}

# 1. The command, linked so a `git pull` here updates it.
mkdir -p "$bin_dir"
ln -sfn "$here/bin/new-wt" "$bin_dir/new-wt"
say "linked $bin_dir/new-wt"

# 2. Each shell: ~/.local/bin on PATH if a new terminal lacks it, and the `new wt` shortcut.
setup_shell() {
  local rc path_line old_block block new_block fn tmp
  case $shell_name in
    fish)
      rc=$config_home/fish/config.fish
      path_line='fish_add_path $HOME/.local/bin' ;;
    zsh)
      rc=${ZDOTDIR:-$HOME}/.zshrc
      path_line='export PATH="$HOME/.local/bin:$PATH"' ;;
    bash)
      # macOS terminals start bash as a login shell, which reads .bash_profile.
      if [ "$(uname -s)" = Darwin ]; then rc=$HOME/.bash_profile; else rc=$HOME/.bashrc; fi
      path_line='export PATH="$HOME/.local/bin:$PATH"' ;;
  esac

  # Our lines in the startup file sit between these markers. Each run rewrites
  # them, so a moved folder never leaves a stale path behind.
  local begin='# >>> new-wt >>>' end='# <<< new-wt <<<'
  old_block=''
  if grep -qxF "$begin" "$rc" 2>/dev/null && grep -qxF "$end" "$rc"; then
    old_block=$(awk -v b="$begin" -v e="$end" '$0==b{on=1} on{print} $0==e{on=0}' "$rc")
  fi

  # Add ~/.local/bin to PATH if a new terminal lacks it, or keep our line if it's what provides it.
  block=''
  case ":$(fresh_path):" in
    *":$bin_dir:"*) case $old_block in *"$path_line"*) block=$path_line ;; esac ;;
    *) block=$path_line ;;
  esac

  if [ "$shell_name" = fish ]; then
    # fish loads functions from their own files, so a link is enough.
    fn=$config_home/fish/functions/new.fish
    if [ "$(readlink "$fn" 2>/dev/null)" = "$here/shell/new.fish" ]; then
      :
    elif [ -e "$fn" ]; then
      warn "$fn already exists, so \`new wt\` wasn't set up for fish (new-wt works on its own)"
    else
      # Also replaces a link left dangling by a move.
      mkdir -p "$(dirname "$fn")"
      ln -sfn "$here/shell/new.fish" "$fn"
      say "linked $fn"
    fi
  else
    block=${block:+$block$'\n'}"source \"$here/shell/new.sh\""
  fi

  new_block=''
  [ -z "$block" ] || new_block=$begin$'\n'$block$'\n'$end
  [ "$new_block" != "$old_block" ] || return 0
  if [ -n "$old_block" ]; then
    # Drop the old lines, and the blank line we put before them. cat > keeps the
    # file itself (and any link to it) in place.
    tmp=$(mktemp)
    awk -v b="$begin" -v e="$end" '
      $0 == b { skip = 1; blank = 0; next }
      skip    { if ($0 == e) skip = 0; next }
      /^$/    { if (blank) print ""; blank = 1; next }
              { if (blank) print ""; blank = 0; print }
      END     { if (blank) print "" }' "$rc" >"$tmp"
    cat "$tmp" >"$rc"
    rm -f "$tmp"
  fi
  if [ -n "$new_block" ]; then
    mkdir -p "$(dirname "$rc")"
    printf '\n%s\n' "$new_block" >>"$rc"
    say "updated $rc:"
    printf '%s\n' "$block" | sed 's/^/     /'
  else
    say "removed new-wt's lines from $rc (a new terminal no longer needs them)"
  fi
}

for shell_name in $shells; do setup_shell; done

# 3. Settings, asked once for all shells. Without a terminal to ask in, keep
# what's there or write the defaults.
RIGHT_PANE=nvim CLAUDE_PROMPT='' CLAUDE_ARGS=''
had_config=0
if [ -f "$config" ]; then
  had_config=1
  # shellcheck source=/dev/null
  . "$config"
fi

if [ -t 0 ]; then
  echo
  echo "Settings, saved in $config (edit it or run this again to change them):"
  echo
  echo "  Command for the right-hand pane, e.g. nvim, lazygit or code ."
  echo "  'shell' opens a plain shell, 'none' leaves claude on its own."
  read -r -p "  [$RIGHT_PANE]: " reply || reply=''
  RIGHT_PANE=${reply:-$RIGHT_PANE}
  echo
  echo "  First message for claude in each new worktree, so it starts right away."
  echo "  {issue}, {branch} and {title} are filled in, e.g."
  echo "  Read Linear issue {issue} and propose a plan before changing code."
  if [ -n "$CLAUDE_PROMPT" ]; then
    echo "  Now: $CLAUDE_PROMPT"
    read -r -p "  [Enter keeps it, - removes it]: " reply || reply=''
  else
    read -r -p "  [Enter for none]: " reply || reply=''
  fi
  case $reply in '') ;; -) CLAUDE_PROMPT='' ;; *) CLAUDE_PROMPT=$reply ;; esac
  echo
fi

if [ -t 0 ] || [ "$had_config" = 0 ]; then
  q() { printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")"; }
  mkdir -p "$(dirname "$config")"
  cat >"$config" <<EOF
# new-wt settings. Read by bash, so keep the quotes.

# Command for the right-hand pane, e.g. nvim, lazygit or "code .".
# "shell" opens a plain shell; "none" leaves claude on its own.
RIGHT_PANE=$(q "$RIGHT_PANE")

# First message for claude in each new worktree, so it starts right away. Empty for none.
# {issue} becomes the issue key in the branch name (WEB-198), {branch} the branch,
# {title} the tab title. A prompt using {issue} is skipped when the branch has no key.
CLAUDE_PROMPT=$(q "$CLAUDE_PROMPT")

# Extra flags for claude, as you'd type them in your shell, e.g. --permission-mode plan
CLAUDE_ARGS=$(q "$CLAUDE_ARGS")
EOF
  say "saved settings to $config"
fi

# 4. What new-wt calls, as a new terminal of each shell would find it.
for shell_name in $shells; do
  path=$(fresh_path)
  [ -n "$path" ] || continue
  missing=''
  for c in git jq herdr claude pnpm "${RIGHT_PANE%% *}"; do
    case $c in '' | shell | none) continue ;; esac
    (PATH=$path; command -v "$c" >/dev/null) || missing="$missing $c"
  done
  if [ -n "$missing" ]; then
    warn "a new $shell_name terminal can't find:$missing"
    warn "new-wt needs git and jq; herdr and claude for the tab; pnpm for pnpm projects."
  fi
done

set -- $shells # at most three
case $# in 1) names=$1 ;; 2) names="$1 and $2" ;; *) names="$1, $2 and $3" ;; esac
echo "✓ new-wt is set up for $names. Open a new terminal, then run: new wt <branch>"
