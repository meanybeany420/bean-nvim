local M = {}
local visited = {}

function M.files()
  local files, seen = {}, {}
  for _, path in ipairs(vim.list_extend(vim.deepcopy(visited), vim.v.oldfiles)) do
    if not path:match("^%w[%w+.-]*://") then
      path = vim.fs.normalize(vim.fn.fnamemodify(path, ":p"))
      if not seen[path] and vim.fn.filereadable(path) == 1 then
        seen[path] = true
        files[#files + 1] = path
      end
    end
  end
  return files
end

local namespace = vim.api.nvim_create_namespace("BeanRecentFiles")

function M.open()
  if vim.bo.filetype == "bean_recent" then
    return
  end
  local origin = vim.api.nvim_get_current_buf()
  local oil_url = vim.bo.filetype == "oil" and vim.api.nvim_buf_get_name(origin) or nil
  local oil_entry = oil_url and require("oil").get_cursor_entry() or nil
  local win = vim.api.nvim_get_current_win()
  local view = vim.fn.winsaveview()
  local options = {}
  for _, name in ipairs({ "number", "relativenumber", "cursorline", "cursorlineopt", "signcolumn", "foldcolumn", "list", "wrap", "spell" }) do
    options[name] = vim.wo[name]
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.api.nvim_buf_set_name(buf, "bean-recent://" .. buf)
  vim.bo[buf].filetype = "bean_recent"
  local files

  local function render()
    files = M.files()
    local lines = { "  Recent files", "  Enter open  / search  r refresh  q back", "" }
    local parent_columns = {}
    for _, path in ipairs(files) do
      local name = vim.fn.fnamemodify(path, ":t")
      local parent = vim.fn.fnamemodify(path, ":h:~")
      local prefix = "  " .. require("config.file_icons").get(path) .. "  " .. vim.fn.strtrans(name) .. "  "
      parent_columns[#parent_columns + 1] = #prefix
      lines[#lines + 1] = prefix .. vim.fn.strtrans(parent) .. "/"
    end
    if #files == 0 then
      lines[4] = "  No recent files yet"
    end
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false
    vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
    local function highlight(line, start, group)
      vim.api.nvim_buf_set_extmark(buf, namespace, line, start, {
        end_col = #lines[line + 1], hl_group = group,
      })
    end
    highlight(0, 0, "Title")
    highlight(1, 0, "Comment")
    for i in ipairs(files) do
      highlight(i + 2, parent_columns[i], "Comment")
    end
    if #files == 0 then
      highlight(3, 0, "Comment")
    end
    vim.api.nvim_win_set_cursor(win, { 4, 0 })
  end

  local function back()
    if vim.api.nvim_buf_is_valid(origin) then
      vim.api.nvim_win_set_buf(win, origin)
      vim.fn.winrestview(view)
    elseif oil_url then
      require("oil").open(oil_url, {}, function()
        if not vim.api.nvim_win_is_valid(win) or vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win)) ~= oil_url then
          return
        end
        vim.api.nvim_win_call(win, function()
          vim.fn.winrestview(view)
          if oil_entry then
            for line = 1, vim.api.nvim_buf_line_count(0) do
              local entry = require("oil").get_entry_on_line(0, line)
              if entry and entry.name == oil_entry.name then
                vim.api.nvim_win_set_cursor(win, { line, view.col })
                break
              end
            end
          end
        end)
      end)
    else
      vim.cmd.enew()
    end
  end

  local function open_file()
    local path = files[vim.api.nvim_win_get_cursor(win)[1] - 3]
    if not path then
      return
    end
    if vim.fn.filereadable(path) ~= 1 then
      vim.notify("File is no longer available: " .. path, vim.log.levels.WARN)
      return
    end
    vim.cmd("hide edit " .. vim.fn.fnameescape(path))
  end

  vim.api.nvim_win_set_buf(win, buf)
  vim.api.nvim_create_autocmd("BufWinLeave", {
    buffer = buf,
    once = true,
    callback = function()
      if vim.api.nvim_win_is_valid(win) then
        for name, value in pairs(options) do
          vim.api.nvim_set_option_value(name, value, { win = win })
        end
      end
    end,
  })
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.cursorline = true
  vim.wo.cursorlineopt = "line"
  vim.wo.signcolumn = "no"
  vim.wo.foldcolumn = "0"
  vim.wo.list = false
  vim.wo.wrap = false
  vim.wo.spell = false
  for key, action in pairs({ ["<CR>"] = open_file, q = back, ["<Esc>"] = back, r = render }) do
    vim.keymap.set("n", key, action, { buffer = buf, silent = true, nowait = true })
  end
  render()
end

function M.setup()
  local function record(event)
    local buf = event and event.buf or vim.api.nvim_get_current_buf()
    local path = vim.api.nvim_buf_get_name(buf)
    if vim.bo[buf].buftype ~= "" or path == "" or vim.fn.filereadable(path) ~= 1 then
      return
    end
    path = vim.fs.normalize(path)
    for i = #visited, 1, -1 do
      if visited[i] == path then
        table.remove(visited, i)
      end
    end
    table.insert(visited, 1, path)
  end
  local group = vim.api.nvim_create_augroup("BeanRecentFiles", { clear = true })
  vim.api.nvim_create_autocmd({ "BufEnter", "BufWritePost" }, { group = group, callback = record })
  vim.api.nvim_create_user_command("RecentFiles", M.open, { desc = "Browse recently opened files" })
  -- User commands must start uppercase; expand only the exact typed :recent command.
  vim.cmd([[cnoreabbrev <expr> recent getcmdtype() == ':' && getcmdline() ==# 'recent' ? 'RecentFiles' : 'recent']])
  record()
end

return M
