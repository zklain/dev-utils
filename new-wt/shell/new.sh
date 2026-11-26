# `new wt <branch> [title]` for zsh and bash. install.sh sources this from your shell's rc file.
new() {
  case "${1:-}" in
    wt) shift; new-wt "$@" ;;
    *) echo "Usage: new wt <branch> [title]   (options: new-wt --help)" >&2; return 1 ;;
  esac
}
