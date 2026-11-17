local M = {}
local defaults

function M.enabled()
  return vim.g.bean_ghost_mode == true
end

function M.preview_enabled()
  return not M.enabled() and vim.g.bean_ghost_text == true
end

function M.configure(opts)
  local previous_enabled = opts.enabled
  opts.enabled = function()
    if M.enabled() then
      return false
    end
    return previous_enabled and previous_enabled() or previous_enabled == nil
  end
  opts.cmdline = opts.cmdline or {}
  opts.term = opts.term or {}
  opts.signature = opts.signature or {}
  defaults = {
    cmdline = opts.cmdline.enabled ~= false,
    term = opts.term.enabled == true,
    signature = opts.signature.enabled == true,
  }
  for name, value in pairs(defaults) do
    opts[name].enabled = value and not M.enabled()
  end
  opts.completion = opts.completion or {}
  opts.completion.ghost_text = opts.completion.ghost_text or {}
  opts.completion.ghost_text.enabled = M.preview_enabled
  return opts
end

function M.guard_noice()
  local signature = require("noice.lsp.signature")
  if signature.bean_ghost_guarded then
    return
  end
  for _, name in ipairs({ "check", "on_signature" }) do
    local original = signature[name]
    signature[name] = function(...)
      if not M.enabled() then
        return original(...)
      end
    end
  end
  signature.bean_ghost_guarded = true
end

function M.set(active)
  vim.g.bean_ghost_mode = active
  local docs = package.loaded["noice.lsp.docs"]
  if active and docs and docs._messages.signature then
    docs.hide(docs._messages.signature)
  end
  local cmp = package.loaded["blink.cmp"]
  if not cmp then
    return
  end
  local config = require("blink.cmp.config")
  if active then
    cmp.cancel()
    cmp.hide_documentation()
    cmp.hide_signature()
    local preview = package.loaded["blink.cmp.completion.windows.ghost_text"]
    if preview then
      preview.clear_preview()
    end
  end
  if defaults then
    for name, value in pairs(defaults) do
      config[name].enabled = value and not active
    end
  end
end

function M.toggle()
  M.set(not M.enabled())
  vim.notify(M.enabled() and "Ghost mode ON — completion OFF" or "Ghost mode OFF — completion restored", vim.log.levels.INFO)
end

function M.setup()
  if vim.g.bean_ghost_mode == nil then
    vim.g.bean_ghost_mode = false
  end
  if vim.g.bean_ghost_text == nil then
    vim.g.bean_ghost_text = false
  end
  vim.api.nvim_create_user_command("Ghost", M.toggle, { desc = "Toggle distraction-free completion mode" })
  vim.cmd([[cnoreabbrev <expr> ghost getcmdtype() == ':' && getcmdline() ==# 'ghost' ? 'Ghost' : 'ghost']])
end

return M
