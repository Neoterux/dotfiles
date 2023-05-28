-- vim: ts=2 tw=2 sw=2 smarttab expandtab
require('mason').setup()
require('mason-lspconfig').setup {
  ensure_installed = { 'lua_ls' },
}
print('lsp is ready')

local capabilities = require('cmp_nvim_lsp').default_capabilities()

-- LSP configuration

local lspconfig = require('lspconfig')


lspconfig.lua_ls.setup{
  capabilities = capabilities,
  settings = {
    Lua = {
      diagnostics = {
        globals = { 'vim' }
      }
    }
  }
}

lspconfig.eslint.setup{
  capabilities = capabilities
}

--[[lspconfig.tsserver.setup{
  capabilities = capabilities
}
--]]

lspconfig.phpactor.setup{}

lspconfig.pyright.setup{}

lspconfig.svelte.setup{}

lspconfig.tailwindcss.setup{}

lspconfig.volar.setup{}

lspconfig.taplo.setup{}

lspconfig.ruby_ls.setup{}

lspconfig.marksman.setup{}

lspconfig.jsonls.setup{
  capabilities = capabilities,
  settings = {
    json = {
      schemas = require('schemastore').json.schemas(),
      validate = { enable = true }
    }
  }
}

lspconfig.cssls.setup{}

lspconfig.asm_lsp.setup{}

lspconfig.yamlls.setup {
  settings = {
    yaml = {
      schemaStore = {
        enable = false
      },
      schemas = require('schemastore').yaml.schemas(),
    }
  }
}

require('typescript').setup{
  disable_commands = false,
  debug = false,
  go_to_source_definition = {
    fallback = true,
  },
  server = {
    capabilities = capabilities,
  },
}

require('clangd_extensions').setup {
  server = {
    capabilities = capabilities,
  },
  extensions = {
    autoSetHints = true,
    inlay_hints = {
      inline = vim.fn.has('nvim-0.10') == 1,
      only_current_line = false,
      only_current_line_autocmd = 'CursorHold',
      show_parameter_hints = true,
      parameter_hints_prefix = '<- ',
      other_hints_prefix = '=> ',
      max_len_align = false,
      max_len_aling_pading = 1,
      highlight = 'Comment',
      priority = 100,
    },
    memory_usage = {
      border = 'none',
    },
    symbol_info = {
      border = 'none',
    },
  },
}

