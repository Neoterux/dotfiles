-- vim: sw=2: foldmethod=marker

local cmp = require('cmp')
local lspkind = require('lspkind')
local luasnip = require('luasnip')

vim.api.nvim_set_keymap("i", "<C-w>", "copilot#Accept()", { expr = true })
vim.api.nvim_set_keymap("s", "<C-w>", "copilot#Accept()", { expr = true })


cmp.setup({
  -- : Snippet configs {{{
  snippet = {
    expand = function(args) 
      vim.fn['UltiSnips#Anon'](args.body)
      require('luasnip').lsp_expand(args.body)
    end,
  },
  -- }}}
  mapping = cmp.mapping.preset.insert({
    ['<C-Tab>'] = function(fallback)
      if cmp.visible then
        cmp.select_next_item()
      else
        fallback()
      end
    end,
    ['<C-d>'] = cmp.mapping(cmp.mapping.scroll_docs(-4), { 'i', 'c' }),
    ['<C-f>'] = cmp.mapping(cmp.mapping.scroll_docs(4), { 'i', 'c' }),
    ['<C-Space>'] = cmp.mapping(cmp.mapping.complete(), { 'i', 'c' }),
    ['<S-Tab>'] = function(fallback)
      if cmp.visible() then
        cmp.select_prev_item()
      else
        fallback()
      end
    end,
    ['<CR>'] = cmp.mapping.confirm({ select = true }),
    ['<C-e>'] = cmp.mapping.abort(),
    ['<Esc>'] = cmp.mapping.close(),
    ['<C-d>'] = cmp.mapping.scroll_docs(-4),
    ['<C-f>'] = cmp.mapping.scroll_docs(4),
  }),
  -- : Sources for completion {{{
  sources = {
    { name = 'nvim_lsp' },
    { name = 'nvim_lua' },
    { name = 'path' },
    { name = 'buffer', keyword_length = 4 },
    { name = 'path' },
    { name = 'omni' },
    { name = 'luasnip' },
--    { name = 'copilot' }
  },
  -- }}}
  completion = {
    keyword_length = 1,
    completeopt = 'menu,noselect',
  },
  view = {
    entries = 'custom',
  },
  formatting = {
    fields = { 'kind', 'abbr' },
    format = lspkind.cmp_format({
      mode = 'symbol_text',
      menu = ({
        nvim_lsp = '[LSP]',
        ultisnip = '[US]',
        nvim_lua = '[Lua]',
        path     = '[Path]',
        buffer   = '[Buffer]',
        omni     = '[Omni]',
        luasnip  = '[LuaSN]',
        copilot  = '[Copilot]',
      })
    })
  },
  experimental = {
    ghost_text = {
      hl_group = "Comment",
    },
  },
  -- Configure the Window visual for popup
  window = { },
  -- :Configure sorting methods {{{
  sorting = {
    comparators = {
      cmp.config.compare.offset,
      cmp.config.compare.exact,
      cmp.config.compare.score,
      require('cmp-under-comparator').under,
      cmp.config.compare.kind,
      cmp.config.compare.sort_text,
      cmp.config.compare.length,
      cmp.config.compare.order,
    },
  },
  -- }}}
})


--  see https://github.com/hrsh7th/nvim-cmp/wiki/Menu-Appearance#how-to-add-visual-studio-code-dark-theme-colors-to-the-menu
vim.cmd[[
  highlight! link CmpItemMenu Comment
  " gray
  highlight! CmpItemAbbrDeprecated guibg=NONE gui=strikethrough guifg=#808080
  " blue
  highlight! CmpItemAbbrMatch guibg=NONE guifg=#569CD6
  highlight! CmpItemAbbrMatchFuzzy guibg=NONE guifg=#569CD6
  " light blue
  highlight! CmpItemKindVariable guibg=NONE guifg=#9CDCFE
  highlight! CmpItemKindInterface guibg=NONE guifg=#9CDCFE
  highlight! CmpItemKindText guibg=NONE guifg=#9CDCFE
  " pink
  highlight! CmpItemKindFunction guibg=NONE guifg=#C586C0
  highlight! CmpItemKindMethod guibg=NONE guifg=#C586C0
  " front
  highlight! CmpItemKindKeyword guibg=NONE guifg=#D4D4D4
  highlight! CmpItemKindProperty guibg=NONE guifg=#D4D4D4
  highlight! CmpItemKindUnit guibg=NONE guifg=#D4D4D4
]]
