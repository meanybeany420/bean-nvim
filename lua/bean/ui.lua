local M = {}

function M.setup()
  local c = require("bean_theme.palette")
  require("mini.icons").setup()
  require("mini.icons").mock_nvim_web_devicons()
  require("mini.pairs").setup()

  require("lualine").setup({
    options = {
      theme = {
        normal = { c = { bg = "#050505", fg = "#5d3036" } },
        inactive = { c = { bg = "#050505", fg = "#5d3036" } },
      },
      globalstatus = true, component_separators = "", section_separators = "",
    },
    sections = {
      lualine_a = { { "mode", fmt = function(s) return s:sub(1, 3) end } },
      lualine_b = {},
      lualine_c = { { "filename", path = 1, padding = { left = 2, right = 2 } } },
      lualine_x = {}, lualine_y = {}, lualine_z = {},
    },
    inactive_sections = {
      lualine_a = {}, lualine_b = {},
      lualine_c = { { "filename", path = 1, padding = { left = 2, right = 2 } } },
      lualine_x = {}, lualine_y = {}, lualine_z = {},
    },
  })

  local notify = require("notify")
  notify.setup({ background_colour = c.bg0, timeout = 3000 })
  vim.notify = notify
  require("config.ghost").guard_noice()
  require("noice").setup({
    cmdline = { enabled = true, view = "cmdline_popup" },
    views = {
      cmdline_popup = {
        position = { row = "100%", col = "70%" },
        size = { width = "60%", height = "auto" },
        border = { style = "none", padding = { 0, 1 } },
        win_options = { winhighlight = { Normal = "Normal", FloatBorder = "Normal" } },
      },
    },
    lsp = {
      override = {
        ["vim.lsp.util.convert_input_to_markdown_lines"] = true,
        ["vim.lsp.util.stylize_markdown"] = true,
      },
    },
    presets = { command_palette = false },
  })
  for _, group in ipairs({ "NoiceCmdlineIcon", "NoiceCmdlineIconCmdline", "NoiceCmdlineIconSearch" }) do
    vim.api.nvim_set_hl(0, group, { fg = c.fg0 })
  end
end

return M
