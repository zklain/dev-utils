function new --description "new wt <branch> [title] — git worktree + herdr tab (claude | nvim), see new-wt --help"
    if not set -q argv[1]
        echo "Usage: new wt <branch> [title]   (options: new-wt --help)" >&2
        return 1
    end

    switch $argv[1]
        case wt
            new-wt $argv[2..]
        case '*'
            echo "new: unknown subcommand '$argv[1]' (expected: wt)" >&2
            return 1
    end
end
