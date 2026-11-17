# nvim-bean

The bits of my old setup I actually use, without LazyVim or lazy.nvim.

Run `nvim-bean`. Plain `nvim` is still the old setup.

- Bean theme, the same statusline and command-line styling
- Oil and file icons (`Space e`), also opens on an empty launch
- scoped file search (`Space f`) and recent files (`Space r` / `:recent`)
- `:ghost` turns completion off; run it again to restore it
- Harpoon: `Space a` adds a file, `Space h` opens the menu, `Space 1`–`4` jumps
- no inline index/type labels
- LSP, diagnostics, formatting and Tree-sitter

Esc goes back from the file views, including to your original Oil selection.

## Files

`init.lua` wires together the small modules in `lua/bean/`.
`lua/config/` contains the file views and completion toggle.
`packages.json` pins the explicit plugins; Neovim manages them with `vim.pack`.
`nvim-pack-lock.json` belongs in Git too.
The Bean theme is included here, with its licence in `licenses/`.

The two setups use separate plugin, cache, undo and state directories.
No database tools, extra explorers, task runner or debugger is bundled.

## Requirements

Neovim with `vim.pack` (0.12+), Git, `fd`, `fzf`, Python 3, a C compiler,
`make`, `curl`, `tar`, Node/npm, Go and a Java 21+ runtime.
A Nerd Font is needed for the same icons as Oil.

## Tests

From this directory:

```sh
NVIM_APPNAME=nvim-bean nvim --headless -u NONE -i NONE -l tests/core.lua
NVIM_APPNAME=nvim-bean nvim --headless -n -i NONE init.lua '+luafile tests/file_finder_fzf.lua'
NVIM_APPNAME=nvim-bean nvim --headless -n -i NONE init.lua '+luafile tests/file_finder_oil.lua'
```

Plugin updates are deliberate: change a pinned revision in `packages.json`,
restart, then use `:lua vim.pack.update()` and review the changes.
