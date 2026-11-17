local M = {}

function M.scopes()
  local oil_dir = vim.bo.filetype == "oil" and require("oil").get_current_dir() or nil
  local current = oil_dir or vim.fn.getcwd()
  local filename = vim.api.nvim_buf_get_name(0)
  local start = oil_dir or (vim.bo.buftype == "" and filename ~= "" and vim.fs.dirname(filename)) or current
  -- Walk literally: vim.fs.root/find normalizes its results with environment expansion.
  local project
  local directory = start
  while directory do
    for _, marker in ipairs({ ".git", "go.mod", "package.json", "pyproject.toml", "Cargo.toml", "Makefile" }) do
      if vim.uv.fs_stat(vim.fs.joinpath(directory, marker)) then
        project = directory
        break
      end
    end
    if project then
      break
    end
    local parent = vim.fs.dirname(directory)
    directory = parent ~= directory and parent or nil
  end
  project = project or current
  return {
    { label = "Project root", path = project },
    { label = oil_dir and "Oil directory" or "Current directory", path = current },
    { label = "Home directory", path = vim.uv.os_homedir() },
    { label = "Choose a directory…" },
  }, oil_dir and 2 or 1
end

local namespace = vim.api.nvim_create_namespace("BeanFileFinder")
local option_names = { "number", "relativenumber", "cursorline", "cursorlineopt", "signcolumn", "foldcolumn", "list", "wrap", "spell" }

local function capture()
  local state = {
    origin = vim.api.nvim_get_current_buf(),
    win = vim.api.nvim_get_current_win(),
    view = vim.fn.winsaveview(),
    options = {},
  }
  if vim.bo.filetype == "oil" then
    state.oil_url = vim.api.nvim_buf_get_name(0)
    state.oil_entry = require("oil").get_cursor_entry()
  end
  for _, name in ipairs(option_names) do
    state.options[name] = vim.wo[name]
  end
  return state
end

local function restore_options(state)
  if vim.api.nvim_win_is_valid(state.win) then
    for name, value in pairs(state.options) do
      vim.api.nvim_set_option_value(name, value, { win = state.win })
    end
  end
end

local function restore_origin(state)
  if vim.api.nvim_buf_is_valid(state.origin) then
    vim.api.nvim_win_set_buf(state.win, state.origin)
    vim.fn.winrestview(state.view)
  elseif state.oil_url then
    require("oil").open(state.oil_url, {}, function()
      if not vim.api.nvim_win_is_valid(state.win)
        or vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(state.win)) ~= state.oil_url then
        return
      end
      vim.api.nvim_win_call(state.win, function()
        vim.fn.winrestview(state.view)
        if state.oil_entry then
          for line = 1, vim.api.nvim_buf_line_count(0) do
            local entry = require("oil").get_entry_on_line(0, line)
            if entry and entry.name == state.oil_entry.name then
              vim.api.nvim_win_set_cursor(state.win, { line, state.view.col })
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

local function fzf_colours()
  local normal = vim.api.nvim_get_hl(0, { name = "Normal", link = false })
  local function colour(group, field, fallback)
    local value = vim.api.nvim_get_hl(0, { name = group, link = false })[field] or fallback
    return string.format("#%06x", value)
  end
  local fg = normal.fg or 0xcccccc
  local bg = normal.bg or 0x101010
  return table.concat({
    "fg:" .. colour("Normal", "fg", fg), "bg:" .. colour("Normal", "bg", bg),
    "fg+:" .. colour("Normal", "fg", fg), "bg+:" .. colour("Visual", "bg", bg),
    "hl:" .. colour("Title", "fg", fg), "hl+:" .. colour("Title", "fg", fg),
    "header:" .. colour("Comment", "fg", fg), "info:" .. colour("Comment", "fg", fg),
    "prompt:" .. colour("Title", "fg", fg), "pointer:" .. colour("Title", "fg", fg),
    "spinner:" .. colour("Title", "fg", fg), "gutter:" .. colour("Normal", "bg", bg),
  }, ",")
end

function M.open()
  if vim.bo.filetype == "bean_find_scope" or vim.bo.filetype == "bean_fuzzy" then
    return
  end
  local scopes, selected = M.scopes()
  local state = capture()
  local buf = vim.api.nvim_create_buf(false, true)
  state.scope = buf
  vim.api.nvim_buf_set_name(buf, "bean-find://" .. buf)
  vim.bo[buf].bufhidden = "hide"
  vim.bo[buf].filetype = "bean_find_scope"
  local lines = { "  Find files", "  Enter choose  j/k move  Esc back", "" }
  for _, scope in ipairs(scopes) do
    local path = scope.path and "  " .. vim.fn.strtrans(vim.fn.fnamemodify(scope.path, ":~")) or ""
    lines[#lines + 1] = "  " .. scope.label .. path
  end
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  for i, group in ipairs({ "Title", "Comment" }) do
    vim.api.nvim_buf_set_extmark(buf, namespace, i - 1, 0, { end_col = #lines[i], hl_group = group })
  end
  for i, scope in ipairs(scopes) do
    if scope.path then
      vim.api.nvim_buf_set_extmark(buf, namespace, i + 2, #scope.label + 4, {
        end_col = #lines[i + 3], hl_group = "Comment",
      })
    end
  end
  vim.api.nvim_win_set_buf(state.win, buf)
  vim.wo.number = false
  vim.wo.relativenumber = false
  vim.wo.cursorline = true
  vim.wo.cursorlineopt = "line"
  vim.wo.signcolumn = "no"
  vim.wo.foldcolumn = "0"
  vim.wo.list = false
  vim.wo.wrap = false
  vim.wo.spell = false
  vim.api.nvim_win_set_cursor(state.win, { selected + 3, 0 })
  local active, job, result, terminal, iconmap = true, nil, nil, nil, nil
  local winclosed
  local function cleanup()
    active = false
    if winclosed then
      pcall(vim.api.nvim_del_autocmd, winclosed)
      winclosed = nil
    end
    if job then
      vim.fn.jobstop(job)
      job = nil
    end
    if result then
      vim.fn.delete(result)
      result = nil
    end
    if iconmap then
      vim.fn.delete(iconmap)
      iconmap = nil
    end
    restore_options(state)
    for _, scratch in ipairs({ buf, terminal }) do
      if scratch and vim.api.nvim_buf_is_valid(scratch) then
        vim.api.nvim_buf_delete(scratch, { force = true })
      end
    end
  end
  local function check_left()
    vim.schedule(function()
      if active and (not vim.api.nvim_win_is_valid(state.win)
        or (vim.api.nvim_win_get_buf(state.win) ~= buf and vim.api.nvim_win_get_buf(state.win) ~= terminal)) then
        cleanup()
      end
    end)
  end
  vim.api.nvim_create_autocmd("BufWinLeave", { buffer = buf, callback = check_left })
  winclosed = vim.api.nvim_create_autocmd("WinClosed", {
    pattern = tostring(state.win), once = true, callback = function() vim.schedule(cleanup) end,
  })
  local function back()
    if not active then
      return
    end
    active = false
    restore_options(state)
    restore_origin(state)
    cleanup()
  end
  for _, key in ipairs({ "q", "<Esc>" }) do
    vim.keymap.set("n", key, back, { buffer = buf, silent = true, nowait = true })
  end

  local function launch(root)
    if root == "~" or root:sub(1, 2) == "~/" then
      root = vim.uv.os_homedir() .. root:sub(2)
    end
    if root:sub(1, 1) ~= "/" then
      root = vim.fs.joinpath(vim.fn.getcwd(), root)
    end
    root = vim.fs.normalize(root, { expand_env = false }):gsub("/$", "")
    if root == "" then
      root = "/"
    end
    if vim.fn.isdirectory(root) ~= 1 then
      vim.notify("Not a directory: " .. root, vim.log.levels.WARN)
      return
    end
    if vim.fn.executable("fzf") ~= 1 or vim.fn.executable("fd") ~= 1 or vim.fn.executable("python3") ~= 1 then
      vim.notify("The file finder requires fzf, fd and python3", vim.log.levels.ERROR)
      return
    end
    local scope_line = vim.api.nvim_win_get_cursor(state.win)[1]
    result = vim.fn.tempname()
    iconmap = vim.fn.tempname()
    vim.fn.writefile({ vim.json.encode(require("config.file_icons").export()) }, iconmap)
    local icon_path = iconmap
    terminal = vim.api.nvim_create_buf(false, true)
    local term = terminal
    vim.api.nvim_win_set_buf(state.win, term)
    vim.bo[term].bufhidden = "wipe"
    vim.api.nvim_create_autocmd("BufWinLeave", { buffer = term, callback = check_left })
    local result_path = result
    local header = "Find files · " .. vim.fn.strtrans(vim.fn.fnamemodify(root, ":~")) .. "\nEnter open · Esc scopes · Ctrl-j/k move"
    job = vim.fn.jobstart({
      "sh", vim.fn.stdpath("config") .. "/scripts/bean-fzf.sh", root, result_path, fzf_colours(), header, icon_path,
    }, {
      term = true,
      cwd = root,
      on_exit = function(_, code)
        vim.schedule(function()
          local file = io.open(result_path, "rb")
          local output = file and file:read("*a") or ""
          if file then
            file:close()
          end
          vim.fn.delete(result_path)
          vim.fn.delete(icon_path)
          job, result, iconmap = nil, nil, nil
          if not active then
            return
          end
          if not vim.api.nvim_win_is_valid(state.win) or vim.api.nvim_win_get_buf(state.win) ~= term then
            cleanup()
            return
          end
          vim.api.nvim_win_call(state.win, function()
            vim.cmd.stopinsert()
            local decorated = output:match("^(.-)%z")
            local relative = decorated and decorated:match("^[^\t]*\t(.*)$")
            local path = relative and vim.fs.joinpath(root, relative) or nil
            if code == 0 and path and vim.fn.filereadable(path) == 1 then
              active = false
              restore_options(state)
              vim.cmd("hide edit " .. vim.fn.fnameescape(path))
              cleanup()
            else
              if code ~= 0 and code ~= 1 and code ~= 130 and code ~= 143 then
                vim.notify("fzf exited with status " .. code, vim.log.levels.ERROR)
              elseif code == 0 and path then
                vim.notify("File is no longer available: " .. path, vim.log.levels.WARN)
              end
              vim.api.nvim_win_set_buf(state.win, buf)
              vim.wo.cursorline = true
              vim.api.nvim_win_set_cursor(state.win, { scope_line, 0 })
            end
          end)
        end)
      end,
    })
    if job <= 0 then
      vim.api.nvim_win_set_buf(state.win, buf)
      vim.fn.delete(result_path)
      vim.fn.delete(icon_path)
      job, result, iconmap = nil, nil, nil
      vim.notify("Could not start fzf", vim.log.levels.ERROR)
      return
    end
    vim.bo[term].filetype = "bean_fuzzy"
    vim.wo.cursorline = false
    vim.wo.number = false
    vim.wo.relativenumber = false
    local running = job
    vim.keymap.set("t", "<Esc>", function()
      vim.api.nvim_chan_send(running, "\27")
    end, { buffer = term, silent = true, nowait = true })
    vim.keymap.set("n", "<Esc>", function()
      vim.fn.jobstop(running)
    end, { buffer = term, silent = true, nowait = true })
    vim.cmd.startinsert()
  end

  vim.keymap.set("n", "<CR>", function()
    local scope = scopes[vim.api.nvim_win_get_cursor(state.win)[1] - 3]
    if not scope then
      return
    end
    if scope.path then
      launch(scope.path)
    else
      vim.ui.input({ prompt = "Find in directory: ", default = scopes[2].path .. "/", completion = "dir" }, function(path)
        if active and path and path ~= "" and vim.api.nvim_win_is_valid(state.win)
          and vim.api.nvim_win_get_buf(state.win) == buf then
          vim.api.nvim_win_call(state.win, function() launch(path) end)
        end
      end)
    end
  end, { buffer = buf, silent = true, nowait = true })
end

-- Share the existing Bean palette and exact file/Oil return policy with
-- content search; each picker still owns its own jobs and scratch buffers.
M.view = { capture = capture, restore = restore_origin, restore_options = restore_options, colours = fzf_colours }

return M
