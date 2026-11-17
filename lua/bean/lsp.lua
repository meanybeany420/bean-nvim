-- Native Neovim LSP; packages must already be on runtimepath (vim.pack).
local M = {}
M.main_servers = { "clangd", "gopls", "pyright", "jdtls", "bashls", "lua_ls" }
-- Mason package identifiers, not lspconfig server names.
M.tools = {
  "clangd", "gopls", "pyright", "jdtls", "bash-language-server", "lua-language-server",
  "shellcheck", "shfmt", "goimports", "gofumpt", "ruff", "stylua", "clang-format", "tree-sitter-cli",
}

---Deliberate in-editor installer; dry_run returns the package plan anywhere.
---First-time headless provisioning is deliberately rejected rather than exiting
---before queued Mason installations have completed on this Neovim build.
function M.install_tools(opts)
  local tools = vim.deepcopy(M.tools)
  if not (opts and opts.dry_run) then
    assert(#vim.api.nvim_list_uis() > 0, "Use :BeanToolsInstall in an interactive nvim-bean session")
    assert(require("mason").has_setup, "Call bean.lsp.setup() before install_tools()")
    vim.cmd.MasonInstall({ args = tools })
  end
  return tools
end

---Offline snapshot: no registry refresh, process spawn, or package installation.
function M.status()
  local registry = require("mason-registry")
  local result = { install_root = vim.fn.stdpath("data") .. "/mason", installed = {}, missing = {} }
  for _, tool in ipairs(M.tools) do
    local list = registry.is_installed(tool) and result.installed or result.missing
    list[#list + 1] = tool
  end
  return result
end

local function client_policy(client)
  -- Keep Tree-sitter/Bean highlighting; Go deliberately retains semantic tokens.
  if client.name ~= "gopls" then
    client.server_capabilities.semanticTokensProvider = nil
  end
  client.server_capabilities.inlayHintProvider = nil
end

local function on_attach(client, bufnr)
  client_policy(client)
  vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
  local function map(lhs, rhs, desc)
    vim.keymap.set("n", lhs, rhs, { buffer = bufnr, silent = true, desc = desc })
  end
  map("gd", vim.lsp.buf.definition, "LSP definition")
  map("gD", vim.lsp.buf.declaration, "LSP declaration")
  map("gr", vim.lsp.buf.references, "LSP references")
  map("gI", vim.lsp.buf.implementation, "LSP implementation")
  map("gy", vim.lsp.buf.type_definition, "LSP type definition")
  map("K", vim.lsp.buf.hover, "LSP hover")
  map("<leader>cr", vim.lsp.buf.rename, "Rename symbol")
  map("<leader>ca", vim.lsp.buf.code_action, "Code action")
  map("<leader>cd", vim.diagnostic.open_float, "Line diagnostics")
  map("<leader>cf", function()
    local ok, conform = pcall(require, "conform")
    if ok then
      conform.format({ bufnr = bufnr, async = true, lsp_format = "fallback" })
    else
      vim.lsp.buf.format({ bufnr = bufnr, async = true })
    end
  end, "Format buffer")
  map("]d", function() vim.diagnostic.jump({ count = 1, float = true }) end, "Next diagnostic")
  map("[d", function() vim.diagnostic.jump({ count = -1, float = true }) end, "Previous diagnostic")
end

function M.setup()
  local capabilities = vim.lsp.protocol.make_client_capabilities()
  local ok, blink = pcall(require, "blink.cmp")
  if ok then
    capabilities = blink.get_lsp_capabilities(capabilities)
  end
  vim.lsp.inlay_hint.enable(false)
  vim.lsp.config("*", { capabilities = capabilities, on_init = client_policy, on_attach = on_attach })
  -- Event policy also covers configs with their own on_attach/on_init callbacks.
  local group = vim.api.nvim_create_augroup("BeanLsp", { clear = true })
  vim.api.nvim_create_autocmd("LspAttach", {
    group = group,
    callback = function(args)
      local client = vim.lsp.get_client_by_id(args.data.client_id)
      if client then on_attach(client, args.buf) end
    end,
  })
  vim.lsp.config("gopls", {
    settings = {
      gopls = {
        gofumpt = true,
        staticcheck = true,
        semanticTokens = true,
        analyses = { unusedparams = true, shadow = true },
      },
    },
  })
  vim.lsp.config("bashls", {
    settings = { bashIde = { shellcheckPath = "shellcheck", shfmt = { path = "shfmt" } } },
  })
  vim.lsp.config("lua_ls", {
    settings = {
      Lua = {
        diagnostics = { globals = { "vim" } },
        workspace = { checkThirdParty = false, library = { vim.env.VIMRUNTIME } },
        telemetry = { enable = false },
      },
    },
  })
  require("mason").setup({ install_root_dir = vim.fn.stdpath("data") .. "/mason" })
  -- Bootstrap is deliberate, not a launch-time ensure_installed loop.
  require("mason-lspconfig").setup({ ensure_installed = {}, automatic_enable = true })
  vim.lsp.enable(M.main_servers)
  vim.api.nvim_create_user_command("BeanToolsInstall", function() M.install_tools() end, {
    desc = "Install Bean primary language servers, formatters and shellcheck (Mason)",
    force = true,
  })
  vim.api.nvim_create_user_command("BeanToolsStatus", function() vim.print(M.status()) end, {
    desc = "Show installed/missing Bean tools without downloading anything",
    force = true,
  })
end

return M
