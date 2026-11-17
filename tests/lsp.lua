-- Run with isolated XDG dirs and NVIM_APPNAME=nvim-bean; see final output.
-- BEAN_TEST_PLUGIN_ROOT optionally points to an existing plugin checkout parent.
local config = vim.fn.fnamemodify(debug.getinfo(1, "S").source:sub(2), ":p:h:h")
vim.opt.runtimepath:prepend(config)
local plugins = vim.env.BEAN_TEST_PLUGIN_ROOT
if plugins then
  for _, name in ipairs({ "nvim-lspconfig", "mason.nvim", "mason-lspconfig.nvim", "blink.cmp" }) do
    if name ~= "blink.cmp" or vim.env.BEAN_TEST_NO_BLINK ~= "1" then
      vim.opt.runtimepath:append(plugins .. "/" .. name)
    end
  end
end
local function check(value, message)
  assert(value, message)
end
local ok, lsp = pcall(require, "bean.lsp")
check(ok, "bean.lsp module must exist: " .. tostring(lsp))
check(vim.deep_equal(lsp.main_servers, { "clangd", "gopls", "pyright", "jdtls", "bashls", "lua_ls" }), "six primary servers")
-- Real Mason and native LSP, but prevent network refresh in this offline test.
require("mason").setup({ registry_cache = { refresh = false } })
lsp.setup()
check(require("mason.settings").current.install_root_dir == vim.fn.stdpath("data") .. "/mason", "isolated Mason root")
check(vim.deep_equal(require("mason-lspconfig.settings").current.ensure_installed, {}), "startup must not install servers")
check(require("mason-lspconfig.settings").current.automatic_enable == true, "enable any user-installed server")
for _, server in ipairs(lsp.main_servers) do
  local cfg = vim.lsp.config[server]
  check(cfg and cfg.cmd and cfg.filetypes, "upstream defaults available for " .. server)
  check(vim.lsp.is_enabled(server), "native LSP enabled for " .. server)
end
check(vim.lsp.config.rust_analyzer.cmd ~= nil, "additional upstream languages remain available")
local go = vim.lsp.config.gopls.settings.gopls
check(go.gofumpt and go.staticcheck and go.semanticTokens, "Go tools and semantic tokens preserved")
check(go.analyses.unusedparams and go.analyses.shadow, "Go analyses preserved")
check(vim.lsp.config.bashls.settings.bashIde.shellcheckPath == "shellcheck", "shellcheck configured")
check(vim.lsp.config.bashls.settings.bashIde.shfmt.path == "shfmt", "shfmt configured")
local caps = vim.lsp.config.pyright.capabilities
if vim.env.BEAN_TEST_NO_BLINK == "1" then
  check(vim.deep_equal(caps, vim.lsp.protocol.make_client_capabilities()), "native capabilities without Blink")
else
  check(caps.textDocument.completion.completionItem.snippetSupport, "completion capabilities merged")
end
check(vim.lsp.config.lua_ls.settings.Lua.diagnostics.globals[1] == "vim", "Lua understands vim")
-- Test policy callbacks directly, without a server or fabricated LSP responses.
local native = vim.lsp.config.pyright
check(type(native.on_init) == "function", "highlight policy must exist")
local non_go = { name = "pyright", server_capabilities = { semanticTokensProvider = {}, inlayHintProvider = true } }
native.on_init(non_go)
check(non_go.server_capabilities.semanticTokensProvider == nil, "non-Go semantic tokens disabled for Bean highlighting")
check(non_go.server_capabilities.inlayHintProvider == nil, "native hint provider disabled")
local go_client = { name = "gopls", server_capabilities = { semanticTokensProvider = {}, inlayHintProvider = true } }
native.on_init(go_client)
check(go_client.server_capabilities.semanticTokensProvider ~= nil, "Go semantic tokens preserved")
local buf = vim.api.nvim_create_buf(true, false)
vim.lsp.inlay_hint.enable(true, { bufnr = buf })
-- Pyright supplies its own upstream on_attach; Bean also applies policy via LspAttach.
vim.lsp.config.bashls.on_attach(non_go, buf)
check(not vim.lsp.inlay_hint.is_enabled({ bufnr = buf }), "attach disables native inlay labels")
check(vim.diagnostic.is_enabled({ bufnr = buf }), "diagnostics remain enabled")
for _, key in ipairs({ "gd", "gD", "gr", "gI", "gy", "K", "<leader>cr", "<leader>ca", "<leader>cd", "<leader>cf", "]d", "[d" }) do
  vim.api.nvim_buf_call(buf, function()
    local map = vim.fn.maparg(key, "n", false, true)
    check(map.buffer == 1 and map.callback ~= nil, "buffer-local LSP mapping: " .. key)
  end)
end
local format_called = false
package.loaded.conform = { format = function(opts) format_called = opts.async and opts.lsp_format == "fallback" end }
vim.api.nvim_buf_call(buf, function() vim.fn.maparg("<leader>cf", "n", false, true).callback() end)
check(format_called, "format mapping prefers Conform with LSP fallback")
package.loaded.conform = nil
local before = #vim.api.nvim_get_autocmds({ group = "BeanLsp" })
lsp.setup()
check(#vim.api.nvim_get_autocmds({ group = "BeanLsp" }) == before, "setup does not duplicate handlers")
local expected_tools = { "clangd", "gopls", "pyright", "jdtls", "bash-language-server", "lua-language-server", "shellcheck", "shfmt", "goimports", "gofumpt", "ruff", "stylua", "clang-format", "tree-sitter-cli" }
check(type(lsp.install_tools) == "function", "explicit bootstrap helper exists")
check(vim.deep_equal(lsp.install_tools({ dry_run = true }), expected_tools), "bootstrap declares primary servers and shell tools")
check(vim.fn.exists(":BeanToolsInstall") == 2 and vim.fn.exists(":BeanToolsStatus") == 2, "deliberate tooling commands")
local status = lsp.status()
check(status.install_root == vim.fn.stdpath("data") .. "/mason", "status reports new Mason root")
check(vim.deep_equal(status.missing, expected_tools) and #status.installed == 0, "status accurately reports absent tools without a registry download")
check(#require("mason-registry").get_installed_package_names() == 0, "test and setup performed no installs")
-- Intercept only the installation command boundary: exercise real native Ex argument
-- dispatch without executing Mason's installer or fabricating any LSP traffic.
local dispatched
vim.api.nvim_create_user_command("MasonInstall", function(opts) dispatched = opts.fargs end, { nargs = "+", force = true })
local accepted, install_error = pcall(lsp.install_tools)
check(not accepted and tostring(install_error):find("interactive"), "headless installs must fail clearly instead of exiting before completion")
check(dispatched == nil, "headless bootstrap must not queue installers")
check(#require("mason-registry").get_installed_package_names() == 0, "intercepted command installed nothing")
print("PASS lsp: native configs, Go/shell/completion, isolated Mason, Bean policies, mappings, Conform, bootstrap/status; no installs")
