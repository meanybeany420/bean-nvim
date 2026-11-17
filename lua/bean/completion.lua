local M = {}

function M.setup()
  require("blink.cmp").setup(require("config.ghost").configure({
    fuzzy = { implementation = "lua" },
    keymap = {
      preset = "none",
      ["<Tab>"] = { "select_next", "snippet_forward", "fallback" },
      ["<S-Tab>"] = { "select_prev", "snippet_backward", "fallback" },
      ["<CR>"] = { "accept", "fallback" },
      ["<C-Space>"] = { "show", "show_documentation", "hide_documentation" },
    },
    sources = { default = { "lsp", "path", "snippets", "buffer" } },
    completion = {
      ghost_text = { show_without_selection = true },
      menu = { border = "rounded" },
      documentation = { auto_show = true, window = { border = "rounded" } },
    },
    appearance = { nerd_font_variant = "mono" },
  }))
end

return M
