local M = {}

function M.setup()
  -- Leader is a prefix, not the built-in Space/right motion. Keep timeout
  -- resolution enabled so longer mappings such as Space f still work.
  vim.keymap.set({ "n", "x" }, "<Space>", "<Nop>", { silent = true })
  vim.keymap.set("n", "<leader>f", function()
    require("config.file_finder").open()
  end, { desc = "Find files (Bean buffer)", nowait = true })
  vim.keymap.set("n", "<leader>/", function()
    require("config.project_grep").open()
  end, { desc = "Search contents (Bean buffer)", nowait = true })
  vim.keymap.set("n", "<leader>r", function()
    require("config.recent_files").open()
  end, { desc = "Recent files (Bean buffer)" })
  for _, key in ipairs({ "Up", "Down", "Left", "Right" }) do
    vim.keymap.set({ "n", "i", "v" }, "<" .. key .. ">", "<Nop>")
    vim.keymap.set({ "n", "i", "v" }, "<S-" .. key .. ">", "<Nop>")
  end
  for key, direction in pairs({ h = "h", j = "j", k = "k", l = "l" }) do
    vim.keymap.set("n", "<C-" .. key .. ">", "<C-w>" .. direction, { desc = "Move to split" })
  end
  vim.keymap.set("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Previous buffer" })
  vim.keymap.set("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
  vim.keymap.set("n", "<Esc>", "<cmd>nohlsearch<cr>", { desc = "Clear search highlight" })
  vim.keymap.set("n", "<leader>qq", "<cmd>qa<cr>", { desc = "Quit Neovim" })
end

return M
