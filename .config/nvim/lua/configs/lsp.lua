-- vim: sw=2: foldmethod=marker
local fn = vim.fn
local api = vim.api
local lsp = vim.lsp

local utils = require('utils')

local custom_attach = function(client, bufnr) 
  local opts = { silent = true, buffer = bufnr }
  vim.keymap.set('n', 'gd', vim.lsp.buf.definition, opts)
  vim.keymap.set('n', '<C-]>', vim.lsp.buf.definition, opts)
  vim.keymap.set('n', 'K', vim.lsp.buf.hover, opts)


  -- The blow command will highlight the current variable and its usages in the buffer.
  if client.resolved_capabilities.document_highlight then
    vim.cmd([[
      hi! link LspReferenceRead Visual
      hi! link LspReferenceText Visual
      hi! link LspReferenceWrite Visual
      augroup lsp_document_highlight
        autocmd! * <buffer>
        autocmd CursorHold <buffer> lua vim.lsp.buf.document_highlight()
        autocmd CursorMoved <buffer> lua vim.lsp.buf.clear_references()
      augroup END
    ]])
  end

  if vim.g.logging_level == 'debug' then
    local msg = string.format("Language server %s started!", client.name)
    vim.notify(msg, 'info', {title = 'Nvim-config'})
  end
end

local capabilities = lsp.protocol.make_client_capabilities()
capabilities = require('cmp_nvim_lsp').update_capabilities(capabilities)
capabilities.textDocument.completion.completionItem.snippetSupport = true

local lspconfig = require('lspconfig')

-- : CLANGD configuration {{{
lspconfig.clangd.setup({
    on_attach = custom_attach,
    capabilities = capabilities,
    filetypes = { "c", "cpp", 'cc' },
    flags = {
        debounce_text_changes = 500
    },
})
-- }}}

-- : LUA Configuration {{{
local sumneko_binary_path = fn.exepath('lua-language-server')
if vim.g.is_linux and sumneko_binary_path ~= '' then
  local sumneko_root_path = fn.fnamemodify(sumneko_binary_path, ':h:h:h')
  local runtime_path = vim.split(package.path, ';')
  table.insert(runtime_path, 'lua/?.lua')
  table.insert(runtime_path, 'lua/?/init.lua')

  lspconfig.sumneko_lua.setup({
    on_attach = custom_attach,
    cmd = { sumneko_binary_path, '-E', sumneko_root_path .. '/main.lua' },
    settings = {
      Lua = {
        runtime = {
          version = 'LuaJIT',
          path = runtime_path,
        },
        diagnostic = {
          globals = { 'vim' }
        },
        workspace = {
          library = api.nvim_get_runtime_file('', true),
        },
        telemetry = {
          enabled = false,
        },
      },
    },
    capabilities = capabilities,
  })
end
-- }}}

-- : Web Dev Configs {{{
lspconfig.html.setup {
  on_attach = custom_attach,
  capabilities = capabilities,
  flags = {
    debounce_text_changes = 150,
  },
}

lspconfig.emmet_ls.setup {
  on_attach = custom_attach,
  capabilities = capabilities,
  flags = {
    debounce_text_changes = 150,
  }
}

-- }}}

-- : VUE Configuration {{{

-- }}}

-- : Haskell Configuration {{{
lspconfig.hls.setup {
  on_attach = custom_attach,
  capabilities = capabilities,
}
-- }}}

-- Change diagnostic signs.
fn.sign_define("DiagnosticSignError", { text = "✗", texthl = "DiagnosticSignError" })
fn.sign_define("DiagnosticSignWarn", { text = "!", texthl = "DiagnosticSignWarn" })
fn.sign_define("DiagnosticSignInformation", { text = "", texthl = "DiagnosticSignInfo" })
fn.sign_define("DiagnosticSignHint", { text = "", texthl = "DiagnosticSignHint" })

vim.diagnostic.config({
  underline = false,
  virtual_text = false,
  signs = true,
  severity_sort = true,
})

lsp.handlers["textDocument/hover"] = lsp.with(vim.lsp.handlers.hover, {
  border = "rounded",
})

