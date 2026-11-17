local M = {}

function M.setup()
  -- Harpoon creates its data directory without parents on a fresh XDG tree.
  vim.fn.mkdir(vim.fn.stdpath("data") .. "/harpoon", "p")
  local harpoon = require("harpoon")
  harpoon:setup()
  vim.keymap.set("n", "<leader>a", function()
    harpoon:list():add()
  end, { desc = "Harpoon Add File" })
  vim.keymap.set("n", "<leader>h", function()
    harpoon.ui:toggle_quick_menu(harpoon:list())
  end, { desc = "Harpoon Menu" })
  for index = 1, 4 do
    vim.keymap.set("n", "<leader>" .. index, function()
      harpoon:list():select(index)
    end, { desc = "Harpoon file " .. index })
  end
end

return M
