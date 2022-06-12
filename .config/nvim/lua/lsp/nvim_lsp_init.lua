-- vim:shiftwidth=2:foldmethod=marker
USER = vim.fn.expand('$USER')
require('lsp/coq_config')
local lsp = require('lspconfig')
local coq = require('coq')

-- General nvim-lsp configuration
-- : attach function Keymaps {{{
local on_attach = function (client, bufnr)
  local function buf_set_keymap(...) vim.api.nvim_buf_set_keymap(bufnr, ...) end
  local function buf_set_option(...) vim.api.nvim_buf_set_option(bufnr, ...) end
  -- Enable completion triggered by <c-x><c-o>
  buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')
  local opts = {noremap = true, silent=true}

  require'lsp_signature'.on_attach{
    bind = true,
    handler_opts = {
      border = 'rounded'
    }
  }
end
-- }}}
-- buf_set_option('omnifunc', 'v:lua.vim.lsp.omnifunc')

-- Python configuration
lsp.pyright.setup(coq.lsp_ensure_capabilities{
  on_attach = on_attach
})

-- C/C++/Obj-C/C++ configuration
lsp.clangd.setup(coq.lsp_ensure_capabilities{

})

lsp.ccls.setup(coq.lsp_ensure_capabilities{
  on_attach = on_attach,
  init_optons = {
    cache = {
      directory = '/tmp/ccls/cache'
    }
  }
})

-- :Haskell configuration{{{
lsp.hie.setup(coq.lsp_ensure_capabilities {
  cmd = {'ghcide', '--lsp'},
})

--lsp.hls.setup(coq.lsp_ensure_capabilities {
--  on_attach = on_attach,

--   root_dir = root_pattern('*.cabal', 'stack.yaml', 'cabal.project', 'package.yaml', 'hie.yaml'),
--}

-- }}}

-- : YAML Configuration {{{
lsp.yamlls.setup(coq.lsp_ensure_capabilities{
  on_attach = on_attach,

})
-- }}}

-- Lua configuration
local sumneko_root_path = '/home/' .. USER .. '/.config/nvim/lua-language-server'
lsp.sumneko_lua.setup(coq.lsp_ensure_capabilities{
  on_attach = on_attach,
  cmd = {'lua-language-server', '-E', sumneko_root_path .. '/main.lua'},
  settings = {
    Lua = {
      runtime = {
        version = 'LuaJIT',
        path = vim.split(package.path, ';')
      },
      diagnostics = {
        globals = {'vim'}
      },
      workspace = {
        library = {
          [vim.fn.expand('$VIMRUNTIME/lua')] = true,
          [vim.fn.expand('$VIMRUNTIME/lua/vim/lsp')] = true
        }
      }
    }
  }
})
