#!/bin/sh
# Called by Neovim with root, result path, Bean colours, header, and icon map.
# NUL delimiters preserve spaces, quotes, and newlines in filenames.
cd -- "$1" || exit 2
fd --type f --hidden --exclude .git --exclude .cache --exclude node_modules \
  --color never --print0 --strip-cwd-prefix . |
  python3 "$(dirname -- "$0")/file_icons.py" "$5" |
  FZF_DEFAULT_OPTS='' FZF_DEFAULT_OPTS_FILE='' FZF_DEFAULT_COMMAND='' \
  fzf --read0 --print0 --no-multi --scheme=path --layout=reverse \
    --delimiter='\t' --nth=2.. --tabstop=4 \
    --border=none --no-separator --info=inline --highlight-line \
    --prompt='> ' --header="$4" --color="$3" \
    --bind='esc:abort,ctrl-j:down,ctrl-k:up' > "$2"
