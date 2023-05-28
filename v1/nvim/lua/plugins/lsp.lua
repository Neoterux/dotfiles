-- vim: tw=2 sw=2 ts=2 expandtab smarttab
return {
  {
    'neovim/nvim-lspconfig',
    dependencies = {
      { 'williamboman/mason.nvim', build = ':MasonUpdate' },
      'williamboman/mason-lspconfig.nvim',
      'hrsh7th/cmp-nvim-lsp',
      {
        'hrsh7th/nvim-cmp',
        dependencies = {
          'L3MON4D3/LuaSnip',
          'b0o/schemastore.nvim',
          'hrsh7th/cmp-cmdline',
          'hrsh7th/cmp-buffer',
          'hrsh7th/cmp-path',
          'saadparwaiz1/cmp_luasnip',
          'p00f/clangd_extensions.nvim',
        },
        config = function()
          require('config.cmp')
        end,
      },
      'jose-elias-alvarez/typescript.nvim',
    },
    config = function()
      require('plugins.lsp.config')
    end,
  }

}

