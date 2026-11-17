local M = {}
local fallback = ""

function M.get(path)
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if not ok then
    return fallback
  end
  return devicons.get_icon(vim.fs.basename(path), nil, { default = true }) or fallback
end

function M.export()
  local mapping = { default = fallback, files = vim.empty_dict(), extensions = vim.empty_dict() }
  local ok, devicons = pcall(require, "nvim-web-devicons")
  if not ok then
    return mapping
  end
  devicons.get_icon("", nil, { default = true })
  mapping.default = devicons.get_default_icon().icon
  local filenames = devicons.get_icons_by_filename()
  local extensions = devicons.get_icons_by_extension()
  -- LazyVim can replace devicons with MiniIcons, whose lists omit fallback types.
  -- Use the installed metadata only for candidate names; resolve every glyph
  -- through the active provider, exactly as Oil does.
  for category, candidates in pairs({ files = filenames, extensions = extensions }) do
    local module = category == "files" and "icons_by_filename" or "icons_by_file_extension"
    local available, defaults = pcall(require, "nvim-web-devicons.default." .. module)
    local names = vim.tbl_extend("force", {}, candidates, available and defaults or {})
    for name in pairs(names) do
      local filename = category == "files" and name or "file." .. name
      mapping[category][name:lower()] = devicons.get_icon(filename, nil, { default = true }) or fallback
    end
  end
  return mapping
end

return M
