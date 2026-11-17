-- Real servers and real formatting; no simulated LSP responses.
local language = assert(vim.env.BEAN_LANGUAGE, "Set BEAN_LANGUAGE")
local fixtures = {
  cpp = { server = "clangd", file = "main.cpp", lines = { "int square(int x){return x*x;}", "int main(){return square(2);}" } },
  go = { server = "gopls", file = "main.go", lines = { "package main", "func square(x int)int{return x*x}", "func main(){_ = square(2)}" } },
  python = { server = "pyright", file = "main.py", lines = { "def square(x):", " return x*x", "", "square(2)" } },
  java = { server = "jdtls", file = "Main.java", lines = { "public class Main{public static int square(int x){return x*x;}public static void main(String[] args){square(2);}}" } },
  bash = { server = "bashls", file = "main.sh", lines = { "#!/usr/bin/env bash", "check(){ echo \"ok\"; }", "check" } },
}
local fixture = assert(fixtures[language], "Unknown test language")
local root = vim.fn.tempname()
vim.fn.mkdir(root .. "/.git", "p")
vim.fn.writefile(fixture.lines, root .. "/" .. fixture.file)
if language == "go" then
  vim.fn.writefile({ "module bean.test/check", "", "go 1.23" }, root .. "/go.mod")
end
local client
local ok, err = pcall(function()
  dofile(vim.fn.stdpath("config") .. "/init.lua")
  vim.notify = function(message) print(message) end
  vim.cmd("edit " .. vim.fn.fnameescape(root .. "/" .. fixture.file))
  assert(vim.bo.filetype ~= "", "Native filetype detection must be enabled")
  local attached = vim.wait(90000, function()
    client = vim.lsp.get_clients({ bufnr = 0, name = fixture.server })[1]
    return client and client.initialized
  end, 100)
  assert(attached and client, fixture.server .. " did not attach; LSP log: " .. vim.lsp.log.get_filename())
  local response = client:request_sync("textDocument/documentSymbol", {
    textDocument = { uri = vim.uri_from_bufnr(0) },
  }, 30000, 0)
  assert(response and not response.err, "documentSymbol request failed")
  assert(type(response.result) == "table" and #response.result > 0, "Server returned no symbols")
  assert(not vim.lsp.inlay_hint.is_enabled({ bufnr = 0 }), "Inline labels must remain off")
  assert(vim.diagnostic.is_enabled({ bufnr = 0 }), "Diagnostics must remain enabled")
  local before = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  local finished, format_error = false, nil
  require("conform").format({ async = false, timeout_ms = 15000, lsp_format = "fallback" }, function(error)
    finished, format_error = true, error
  end)
  assert(vim.wait(20000, function() return finished end), "Formatting callback did not finish")
  assert(not format_error, tostring(format_error))
  local after = table.concat(vim.api.nvim_buf_get_lines(0, 0, -1, false), "\n")
  assert(before ~= after, "Real formatter must change the deliberately unformatted fixture")
  assert(vim.treesitter.get_parser(0):parse()[1], "Real Tree-sitter parser must parse the fixture")
  io.stdout:write("PASS " .. language .. ": " .. client.name .. " attached, " .. #response.result .. " symbols, real formatting, syntax tree, labels off\n")
  io.stdout:flush()
end)
if client then
  client:stop(true)
  vim.wait(2000, function() return client:is_stopped() end)
end
vim.fn.delete(root, "rf")
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd("cquit 1")
end
vim.cmd("qa!")
